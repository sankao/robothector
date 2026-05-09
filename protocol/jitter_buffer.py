"""Jitter buffer — reorders out-of-order UDP audio packets and emits a
steady PCM stream, filling gaps with silence on irrecoverable loss.

Usage pattern:

    jb = JitterBuffer()
    while True:
        # one thread feeds: jb.push(packet)
        # another thread drains:
        chunk = jb.pop()       # returns bytes (PCM payload) or None if not ready
        if chunk is None:
            time.sleep(0.005)  # nothing to play yet; wait briefly
            continue
        sink.write(chunk)

Design:
- target_depth: the buffer waits until it has this many packets queued
  before emitting the first one. Higher target = more latency, more
  resilience to bursty arrival.
- max_depth: hard cap; older packets are dropped to make room.
- On gap detection (next_seq missing), the buffer emits silence of the
  same sample count as the most recent packet, then advances.
"""

from __future__ import annotations

import heapq
from dataclasses import dataclass

from .audio_packet import (
    AudioPacket,
    DEFAULT_SAMPLES_PER_PACKET,
    silence_payload,
)


@dataclass
class JitterBufferStats:
    pushed: int = 0
    popped: int = 0
    silence_emitted: int = 0
    duplicates_dropped: int = 0
    late_dropped: int = 0
    overflow_dropped: int = 0


class JitterBuffer:
    def __init__(
        self,
        target_depth: int = 2,
        max_depth: int = 8,
        default_samples: int = DEFAULT_SAMPLES_PER_PACKET,
    ) -> None:
        if target_depth < 1:
            raise ValueError("target_depth must be >= 1")
        if max_depth < target_depth:
            raise ValueError("max_depth must be >= target_depth")
        self.target_depth = target_depth
        self.max_depth = max_depth
        self.default_samples = default_samples
        self._heap: list[tuple[int, int, AudioPacket]] = []
        self._tiebreak = 0  # for heap stability
        self._next_seq: int | None = None
        self._last_sample_count = default_samples
        self._primed = False
        self._seen_seqs: set[int] = set()
        self.stats = JitterBufferStats()

    def __len__(self) -> int:
        return len(self._heap)

    def push(self, packet: AudioPacket) -> None:
        """Add a received packet. Idempotent on duplicates."""
        self.stats.pushed += 1
        # too late?
        if self._next_seq is not None and packet.seq < self._next_seq:
            self.stats.late_dropped += 1
            return
        # duplicate?
        if packet.seq in self._seen_seqs:
            self.stats.duplicates_dropped += 1
            return
        self._seen_seqs.add(packet.seq)
        heapq.heappush(self._heap, (packet.seq, self._tiebreak, packet))
        self._tiebreak += 1
        # cap depth — drop OLDEST (lowest seq) past max
        while len(self._heap) > self.max_depth:
            _, _, dropped = heapq.heappop(self._heap)
            self._seen_seqs.discard(dropped.seq)
            self.stats.overflow_dropped += 1
            # if we drop something, the receiver must skip ahead too
            if self._next_seq is not None and dropped.seq >= self._next_seq:
                self._next_seq = dropped.seq + 1

    def pop(self) -> bytes | None:
        """Pop one chunk worth of PCM payload, or None if not yet ready.

        Returns silence of the previous packet's size on irrecoverable loss.
        """
        if not self._heap:
            return None

        # priming: wait until we have target_depth queued before first emit
        if not self._primed:
            if len(self._heap) < self.target_depth:
                return None
            self._primed = True
            _, _, pkt = heapq.heappop(self._heap)
            self._seen_seqs.discard(pkt.seq)
            self._next_seq = pkt.seq + 1
            self._last_sample_count = pkt.sample_count
            self.stats.popped += 1
            return pkt.payload

        # primed: try to deliver next_seq
        head_seq, _, head_pkt = self._heap[0]
        if head_seq == self._next_seq:
            heapq.heappop(self._heap)
            self._seen_seqs.discard(head_pkt.seq)
            self._next_seq += 1
            self._last_sample_count = head_pkt.sample_count
            self.stats.popped += 1
            return head_pkt.payload

        # gap. Three cases:
        # 1. We have plenty buffered but next_seq never came -> emit silence,
        #    advance, hope next_seq+1 is at the head.
        # 2. We have very little buffered -> wait, the missing one might still arrive.
        # 3. The gap is huge -> resync to whatever's at the head.
        gap = head_seq - self._next_seq
        if gap > self.max_depth:
            # resync — the missing range is bigger than we'd ever buffer
            heapq.heappop(self._heap)
            self._seen_seqs.discard(head_pkt.seq)
            self._next_seq = head_pkt.seq + 1
            self._last_sample_count = head_pkt.sample_count
            self.stats.popped += 1
            return head_pkt.payload
        if len(self._heap) >= self.target_depth:
            # buffer is full enough — declare the missing packet lost
            self._next_seq += 1
            self.stats.silence_emitted += 1
            return silence_payload(self._last_sample_count)
        # otherwise: wait, missing packet may still show up
        return None
