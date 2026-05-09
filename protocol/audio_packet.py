"""Wire format for PCM audio over UDP.

Each `AudioPacket` is one UDP datagram. Header is 12 bytes big-endian
followed by a S16_LE mono PCM payload of `sample_count * 2` bytes.

  bytes 0..1   magic    0xAB 0xCD
  bytes 2..5   seq      uint32, monotonic per stream
  bytes 6..9   ts_ms    uint32, sender's monotonic clock in ms (mod 2^32)
  bytes 10..11 count    uint16, number of samples in payload
  bytes 12..   payload  count * int16 little-endian, mono PCM

This module is pure data — no asyncio, no networking, no audio devices.
Both sides import it.
"""

from __future__ import annotations

import struct
from dataclasses import dataclass

MAGIC = b"\xab\xcd"
HEADER_SIZE = 12
HEADER_FMT = ">2sIIH"  # magic, seq, ts_ms, sample_count

SAMPLE_RATE_HZ = 16000
BYTES_PER_SAMPLE = 2  # S16_LE mono
DEFAULT_SAMPLES_PER_PACKET = 640  # 40 ms @ 16 kHz
MAX_SAMPLES_PER_PACKET = 4096  # sanity guard — 256 ms is way past anything sensible


@dataclass(frozen=True)
class AudioPacket:
    seq: int
    timestamp_ms: int
    sample_count: int
    payload: bytes

    def __post_init__(self) -> None:
        if not 0 <= self.seq < 2**32:
            raise ValueError(f"seq out of uint32 range: {self.seq}")
        if not 0 <= self.timestamp_ms < 2**32:
            raise ValueError(f"timestamp_ms out of uint32 range: {self.timestamp_ms}")
        if not 0 < self.sample_count <= MAX_SAMPLES_PER_PACKET:
            raise ValueError(
                f"sample_count out of (0, {MAX_SAMPLES_PER_PACKET}]: {self.sample_count}"
            )
        if len(self.payload) != self.sample_count * BYTES_PER_SAMPLE:
            raise ValueError(
                f"payload size {len(self.payload)} does not match "
                f"sample_count * 2 = {self.sample_count * BYTES_PER_SAMPLE}"
            )

    def to_bytes(self) -> bytes:
        header = struct.pack(
            HEADER_FMT, MAGIC, self.seq, self.timestamp_ms, self.sample_count
        )
        return header + self.payload

    @classmethod
    def from_bytes(cls, data: bytes) -> "AudioPacket":
        if len(data) < HEADER_SIZE:
            raise ValueError(f"packet too short ({len(data)} bytes)")
        magic, seq, ts_ms, sample_count = struct.unpack(
            HEADER_FMT, data[:HEADER_SIZE]
        )
        if magic != MAGIC:
            raise ValueError(f"bad magic: {magic.hex()}")
        payload = data[HEADER_SIZE:]
        # Constructor enforces payload-size match against sample_count.
        return cls(
            seq=seq,
            timestamp_ms=ts_ms,
            sample_count=sample_count,
            payload=payload,
        )

    @property
    def duration_ms(self) -> float:
        return 1000.0 * self.sample_count / SAMPLE_RATE_HZ


def silence_payload(sample_count: int) -> bytes:
    """A payload of `sample_count` samples of pure silence (S16 zeros)."""
    return b"\x00\x00" * sample_count
