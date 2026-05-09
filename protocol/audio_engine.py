"""Reusable UDP audio sender / receiver primitives.

Both server-side and client-side audio just compose one
`AudioStreamSender` (mic → UDP) and one `AudioStreamReceiver` (UDP →
speaker). The two sides differ only in which sockets/addresses they
plug into.

Each primitive owns a single daemon thread. Sockets and audio devices
are injected so tests can use FakeAudio* + loopback `127.0.0.1` UDP.
"""

from __future__ import annotations

import socket
import threading
import time
from typing import Optional

from .audio_io import AudioSink, AudioSource
from .audio_packet import (
    BYTES_PER_SAMPLE,
    DEFAULT_SAMPLES_PER_PACKET,
    AudioPacket,
    silence_payload,
)
from .jitter_buffer import JitterBuffer

RECV_TIMEOUT_S = 0.1
THREAD_JOIN_TIMEOUT_S = 1.0


class AudioStreamSender:
    """Read PCM from an `AudioSource`, packetise, send over UDP."""

    def __init__(
        self,
        source: AudioSource,
        socket_: socket.socket,
        dest_host: str,
        dest_port: int,
        samples_per_packet: int = DEFAULT_SAMPLES_PER_PACKET,
        thread_name: str = "audio-sender",
    ) -> None:
        self.source = source
        self._sock = socket_
        self._dest_host = dest_host
        self._dest_port = dest_port
        self.samples_per_packet = samples_per_packet
        self._thread_name = thread_name
        self._thread: Optional[threading.Thread] = None
        self._stop = threading.Event()
        self._seq = 0

    def update_dest(self, host: str, port: int | None = None) -> None:
        """Re-target the stream without restarting the thread."""
        self._dest_host = host
        if port is not None:
            self._dest_port = port

    def start(self) -> None:
        if self._thread is not None and self._thread.is_alive():
            return
        self._stop.clear()
        self._seq = 0
        self._thread = threading.Thread(
            target=self._loop, name=self._thread_name, daemon=True
        )
        self._thread.start()

    def stop(self) -> None:
        self._stop.set()
        t = self._thread
        if t is not None:
            t.join(timeout=THREAD_JOIN_TIMEOUT_S)
        self._thread = None

    def is_running(self) -> bool:
        return self._thread is not None and self._thread.is_alive()

    def _loop(self) -> None:
        try:
            self.source.start()
        except Exception as e:
            print(f"[audio_engine] sender source.start failed: {e}")
            return
        try:
            while not self._stop.is_set():
                payload = self.source.read(self.samples_per_packet, timeout=0.5)
                if not payload:
                    continue
                payload = self._normalise(payload)
                ts_ms = int(time.monotonic() * 1000) & 0xFFFFFFFF
                pkt = AudioPacket(
                    seq=self._seq,
                    timestamp_ms=ts_ms,
                    sample_count=self.samples_per_packet,
                    payload=payload,
                )
                try:
                    self._sock.sendto(pkt.to_bytes(),
                                      (self._dest_host, self._dest_port))
                except OSError as e:
                    print(f"[audio_engine] sender sendto failed: {e}")
                    break
                self._seq = (self._seq + 1) & 0xFFFFFFFF
        finally:
            try:
                self.source.stop()
            except Exception:
                pass

    def _normalise(self, payload: bytes) -> bytes:
        target = self.samples_per_packet * BYTES_PER_SAMPLE
        if len(payload) == target:
            return payload
        if len(payload) < target:
            short_samples = (target - len(payload)) // BYTES_PER_SAMPLE
            return payload + silence_payload(short_samples)
        return payload[:target]


class AudioStreamReceiver:
    """Receive UDP audio packets, jitter-buffer them, write to `AudioSink`."""

    def __init__(
        self,
        sink: AudioSink,
        socket_: socket.socket,
        samples_per_packet: int = DEFAULT_SAMPLES_PER_PACKET,
        thread_name: str = "audio-receiver",
        jitter_target_depth: int = 2,
        jitter_max_depth: int = 8,
    ) -> None:
        self.sink = sink
        self._sock = socket_
        self.samples_per_packet = samples_per_packet
        self._thread_name = thread_name
        self._jitter_target = jitter_target_depth
        self._jitter_max = jitter_max_depth
        self._thread: Optional[threading.Thread] = None
        self._stop = threading.Event()
        self._sock.settimeout(RECV_TIMEOUT_S)

    def start(self) -> None:
        if self._thread is not None and self._thread.is_alive():
            return
        self._stop.clear()
        self._thread = threading.Thread(
            target=self._loop, name=self._thread_name, daemon=True
        )
        self._thread.start()

    def stop(self) -> None:
        self._stop.set()
        t = self._thread
        if t is not None:
            t.join(timeout=THREAD_JOIN_TIMEOUT_S)
        self._thread = None

    def is_running(self) -> bool:
        return self._thread is not None and self._thread.is_alive()

    def _loop(self) -> None:
        try:
            self.sink.start()
        except Exception as e:
            print(f"[audio_engine] receiver sink.start failed: {e}")
            return
        jb = JitterBuffer(
            target_depth=self._jitter_target,
            max_depth=self._jitter_max,
            default_samples=self.samples_per_packet,
        )
        try:
            while not self._stop.is_set():
                try:
                    data, _addr = self._sock.recvfrom(8192)
                except socket.timeout:
                    self._drain(jb)
                    continue
                except OSError:
                    break
                try:
                    pkt = AudioPacket.from_bytes(data)
                except ValueError:
                    continue
                jb.push(pkt)
                self._drain(jb)
        finally:
            try:
                self.sink.stop()
            except Exception:
                pass

    def _drain(self, jb: JitterBuffer) -> None:
        while True:
            chunk = jb.pop()
            if chunk is None:
                break
            self.sink.write(chunk)
