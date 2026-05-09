"""Tests for protocol.jitter_buffer."""

from __future__ import annotations

import pytest

from protocol import (
    AudioPacket,
    JitterBuffer,
    silence_payload,
)


def pkt(seq: int, n_samples: int = 320, ts_ms: int | None = None,
        fill: int = 0) -> AudioPacket:
    """Helper: build an AudioPacket with a known fill value in its payload."""
    payload = (fill.to_bytes(2, "little", signed=True)) * n_samples
    return AudioPacket(
        seq=seq,
        timestamp_ms=ts_ms if ts_ms is not None else seq * 20,
        sample_count=n_samples,
        payload=payload,
    )


class TestPriming:
    def test_pop_returns_none_until_target_depth_reached(self) -> None:
        jb = JitterBuffer(target_depth=3)
        jb.push(pkt(0))
        assert jb.pop() is None
        jb.push(pkt(1))
        assert jb.pop() is None
        jb.push(pkt(2))
        # now 3 packets queued, should emit
        out = jb.pop()
        assert out is not None

    def test_pop_returns_first_in_seq_after_priming(self) -> None:
        jb = JitterBuffer(target_depth=2)
        jb.push(pkt(5, fill=5))
        jb.push(pkt(6, fill=6))
        # priming completes — first emit
        first = jb.pop()
        assert first == pkt(5, fill=5).payload

    def test_priming_handles_out_of_order_arrival(self) -> None:
        jb = JitterBuffer(target_depth=2)
        jb.push(pkt(7, fill=7))
        jb.push(pkt(5, fill=5))
        jb.push(pkt(6, fill=6))
        # heap orders by seq, lowest emitted first
        assert jb.pop() == pkt(5, fill=5).payload
        assert jb.pop() == pkt(6, fill=6).payload
        assert jb.pop() == pkt(7, fill=7).payload


class TestSequentialDelivery:
    def test_in_order_packets_emit_in_order(self) -> None:
        """Interleaved push/pop, matching real audio streaming usage."""
        jb = JitterBuffer(target_depth=2)
        # prime
        jb.push(pkt(0, fill=0))
        jb.push(pkt(1, fill=1))
        outs: list[bytes] = []
        outs.append(jb.pop())  # type: ignore[arg-type]
        for i in range(2, 10):
            jb.push(pkt(i, fill=i))
            outs.append(jb.pop())  # type: ignore[arg-type]
        # we should have got [0, 1, 2, ..., 8]; final 9 is still in buffer
        assert len(outs) == 9
        for i, payload in enumerate(outs):
            assert payload == pkt(i, fill=i).payload, f"idx {i} mismatch"
        # drain the last
        assert jb.pop() == pkt(9, fill=9).payload

    def test_burst_push_within_max_depth_preserves_order(self) -> None:
        jb = JitterBuffer(target_depth=2, max_depth=20)
        for i in range(10):
            jb.push(pkt(i, fill=i))
        for i in range(10):
            assert jb.pop() == pkt(i, fill=i).payload, f"idx {i} mismatch"

    def test_burst_push_beyond_max_depth_drops_oldest(self) -> None:
        jb = JitterBuffer(target_depth=2, max_depth=4)
        for i in range(10):
            jb.push(pkt(i, fill=i))
        assert jb.stats.overflow_dropped == 6
        # only the most recent 4 survive: seqs 6,7,8,9
        # priming pops seq 6 first
        assert jb.pop() == pkt(6, fill=6).payload
        assert jb.pop() == pkt(7, fill=7).payload
        assert jb.pop() == pkt(8, fill=8).payload
        assert jb.pop() == pkt(9, fill=9).payload

    def test_pop_when_empty_returns_none(self) -> None:
        jb = JitterBuffer()
        assert jb.pop() is None


class TestLossAndSilence:
    def test_lost_packet_emits_silence_when_buffer_full_enough(self) -> None:
        jb = JitterBuffer(target_depth=2)
        jb.push(pkt(0, n_samples=320, fill=1))
        jb.push(pkt(1, n_samples=320, fill=1))
        # prime: emit 0
        assert jb.pop() == pkt(0, fill=1).payload
        # now next_seq=1, push seq 2 and 3 (skip 1... wait, seq 1 was already received)
        # Let's redo: prime with seq 0, leave 1 missing, push 2 and 3
        jb2 = JitterBuffer(target_depth=2)
        jb2.push(pkt(0, n_samples=320, fill=10))
        jb2.push(pkt(2, n_samples=320, fill=12))
        # priming happens at depth=2, emits seq 0
        assert jb2.pop() == pkt(0, fill=10).payload
        # next_seq=1, head is seq 2 — gap. Need >= target_depth queued.
        # Push seq 3 to ensure depth >= 2.
        jb2.push(pkt(3, n_samples=320, fill=13))
        # head is still seq 2, gap of 1, depth=2 (>= target). Should emit silence.
        out = jb2.pop()
        assert out == silence_payload(320)
        assert jb2.stats.silence_emitted == 1
        # next pop should now get seq 2
        assert jb2.pop() == pkt(2, fill=12).payload
        assert jb2.pop() == pkt(3, fill=13).payload

    def test_late_packet_dropped_after_advance(self) -> None:
        jb = JitterBuffer(target_depth=1)
        jb.push(pkt(5, fill=5))
        # priming with depth 1
        assert jb.pop() == pkt(5, fill=5).payload  # next_seq=6
        # late arrival of seq 4 — should be dropped
        jb.push(pkt(4, fill=4))
        assert jb.stats.late_dropped == 1
        # now push 6, should emit
        jb.push(pkt(6, fill=6))
        assert jb.pop() == pkt(6, fill=6).payload


class TestDuplicates:
    def test_duplicate_seq_dropped(self) -> None:
        jb = JitterBuffer(target_depth=1)
        jb.push(pkt(0, fill=1))
        jb.push(pkt(0, fill=99))  # duplicate seq, different payload
        assert jb.stats.duplicates_dropped == 1
        assert jb.pop() == pkt(0, fill=1).payload  # first one wins


class TestOverflow:
    def test_oversize_buffer_drops_oldest(self) -> None:
        jb = JitterBuffer(target_depth=1, max_depth=3)
        # arrive far out of order; buffer caps at 3
        for seq in [10, 20, 30, 40]:
            jb.push(pkt(seq, fill=seq))
        assert len(jb) == 3
        assert jb.stats.overflow_dropped == 1


class TestResync:
    def test_huge_gap_triggers_resync(self) -> None:
        jb = JitterBuffer(target_depth=1, max_depth=4)
        jb.push(pkt(0, fill=0))
        assert jb.pop() == pkt(0, fill=0).payload  # next_seq=1
        # huge gap — seq 1000 arrives; gap (999) > max_depth (4), resync
        jb.push(pkt(1000, fill=99))
        out = jb.pop()
        assert out == pkt(1000, fill=99).payload


class TestStats:
    def test_stats_track_pushes_and_pops(self) -> None:
        jb = JitterBuffer(target_depth=2)
        for i in range(5):
            jb.push(pkt(i))
        for _ in range(5):
            jb.pop()
        assert jb.stats.pushed == 5
        assert jb.stats.popped == 5


class TestConstructorValidation:
    def test_target_depth_must_be_positive(self) -> None:
        with pytest.raises(ValueError):
            JitterBuffer(target_depth=0)

    def test_max_depth_must_be_at_least_target(self) -> None:
        with pytest.raises(ValueError):
            JitterBuffer(target_depth=5, max_depth=2)
