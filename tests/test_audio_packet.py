"""Tests for protocol.audio_packet — UDP wire format."""

from __future__ import annotations

import pytest

from protocol import (
    BYTES_PER_SAMPLE,
    DEFAULT_SAMPLES_PER_PACKET,
    HEADER_SIZE,
    MAGIC,
    AudioPacket,
    silence_payload,
)
from protocol.audio_packet import MAX_SAMPLES_PER_PACKET, SAMPLE_RATE_HZ


def make_payload(n_samples: int, fill: int = 0) -> bytes:
    return (fill.to_bytes(2, "little", signed=True)) * n_samples


class TestPacketRoundTrip:
    def test_default_packet_size(self) -> None:
        n = DEFAULT_SAMPLES_PER_PACKET
        pkt = AudioPacket(seq=0, timestamp_ms=0, sample_count=n,
                          payload=make_payload(n))
        wire = pkt.to_bytes()
        assert len(wire) == HEADER_SIZE + n * BYTES_PER_SAMPLE
        assert wire[:2] == MAGIC

    def test_round_trip_preserves_all_fields(self) -> None:
        original = AudioPacket(
            seq=0xDEADBEEF,
            timestamp_ms=12345678,
            sample_count=320,
            payload=make_payload(320, fill=1234),
        )
        decoded = AudioPacket.from_bytes(original.to_bytes())
        assert decoded == original

    @pytest.mark.parametrize("n", [1, 320, 640, 1024, MAX_SAMPLES_PER_PACKET])
    def test_various_sizes_round_trip(self, n: int) -> None:
        pkt = AudioPacket(seq=0, timestamp_ms=0, sample_count=n,
                          payload=make_payload(n))
        assert AudioPacket.from_bytes(pkt.to_bytes()) == pkt

    def test_seq_at_uint32_max(self) -> None:
        n = 320
        pkt = AudioPacket(seq=2**32 - 1, timestamp_ms=0, sample_count=n,
                          payload=make_payload(n))
        decoded = AudioPacket.from_bytes(pkt.to_bytes())
        assert decoded.seq == 2**32 - 1


class TestPacketValidation:
    def test_rejects_seq_too_large(self) -> None:
        with pytest.raises(ValueError, match="seq"):
            AudioPacket(seq=2**32, timestamp_ms=0, sample_count=1, payload=b"\x00\x00")

    def test_rejects_negative_seq(self) -> None:
        with pytest.raises(ValueError, match="seq"):
            AudioPacket(seq=-1, timestamp_ms=0, sample_count=1, payload=b"\x00\x00")

    def test_rejects_zero_sample_count(self) -> None:
        with pytest.raises(ValueError, match="sample_count"):
            AudioPacket(seq=0, timestamp_ms=0, sample_count=0, payload=b"")

    def test_rejects_too_large_sample_count(self) -> None:
        with pytest.raises(ValueError, match="sample_count"):
            AudioPacket(
                seq=0,
                timestamp_ms=0,
                sample_count=MAX_SAMPLES_PER_PACKET + 1,
                payload=make_payload(MAX_SAMPLES_PER_PACKET + 1),
            )

    def test_rejects_payload_size_mismatch(self) -> None:
        with pytest.raises(ValueError, match="payload size"):
            # claims 320 samples but only 100 bytes payload (= 50 samples)
            AudioPacket(seq=0, timestamp_ms=0, sample_count=320,
                        payload=b"\x00" * 100)


class TestFromBytesErrors:
    def test_too_short(self) -> None:
        with pytest.raises(ValueError, match="too short"):
            AudioPacket.from_bytes(b"\xab\xcd\x00")

    def test_bad_magic(self) -> None:
        n = 10
        # craft a buffer with wrong magic but otherwise valid
        import struct
        bad = struct.pack(">2sIIH", b"\x00\x00", 0, 0, n) + make_payload(n)
        with pytest.raises(ValueError, match="bad magic"):
            AudioPacket.from_bytes(bad)

    def test_truncated_payload(self) -> None:
        n = 320
        pkt = AudioPacket(seq=0, timestamp_ms=0, sample_count=n,
                          payload=make_payload(n))
        truncated = pkt.to_bytes()[:-10]
        with pytest.raises(ValueError, match="payload size"):
            AudioPacket.from_bytes(truncated)


class TestDuration:
    def test_duration_for_default_packet(self) -> None:
        pkt = AudioPacket(seq=0, timestamp_ms=0,
                          sample_count=DEFAULT_SAMPLES_PER_PACKET,
                          payload=make_payload(DEFAULT_SAMPLES_PER_PACKET))
        # 640 samples / 16000 Hz = 40 ms
        assert pkt.duration_ms == pytest.approx(40.0)

    def test_duration_for_smaller_packet(self) -> None:
        # 320 samples / 16000 Hz = 20 ms
        pkt = AudioPacket(seq=0, timestamp_ms=0, sample_count=320,
                          payload=make_payload(320))
        assert pkt.duration_ms == pytest.approx(20.0)


class TestSilencePayload:
    def test_returns_zeros_of_right_length(self) -> None:
        n = 640
        s = silence_payload(n)
        assert len(s) == n * BYTES_PER_SAMPLE
        assert s == b"\x00" * (n * BYTES_PER_SAMPLE)
        # roundtrip-safe: can build an AudioPacket from it
        pkt = AudioPacket(seq=0, timestamp_ms=0, sample_count=n, payload=s)
        assert pkt.sample_count == n


def test_sample_rate_constant() -> None:
    assert SAMPLE_RATE_HZ == 16000
