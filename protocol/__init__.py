"""Shared wire protocol between client and server.

Both `client.*` and `server.*` import from here. Keep this package free
of platform-specific deps (no GPIO, no pygame, no sounddevice) so it
imports cleanly everywhere — including under pytest on a CI runner with
no audio hardware.
"""

from .audio_packet import (
    AudioPacket,
    BYTES_PER_SAMPLE,
    DEFAULT_SAMPLES_PER_PACKET,
    HEADER_SIZE,
    MAGIC,
    SAMPLE_RATE_HZ,
    silence_payload,
)
from .jitter_buffer import JitterBuffer, JitterBufferStats
from .messages import (
    AudioListenMessage,
    AudioTalkMessage,
    DriveMessage,
    ErrorMessage,
    ModeMessage,
    PingMessage,
    PongMessage,
    StateMessage,
    parse_client_message,
    serialize,
)

__all__ = [
    "AudioListenMessage",
    "AudioPacket",
    "AudioTalkMessage",
    "BYTES_PER_SAMPLE",
    "DEFAULT_SAMPLES_PER_PACKET",
    "DriveMessage",
    "ErrorMessage",
    "HEADER_SIZE",
    "JitterBuffer",
    "JitterBufferStats",
    "MAGIC",
    "ModeMessage",
    "PingMessage",
    "PongMessage",
    "SAMPLE_RATE_HZ",
    "StateMessage",
    "parse_client_message",
    "serialize",
    "silence_payload",
]
