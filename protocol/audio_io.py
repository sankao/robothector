"""Audio I/O abstraction.

Defines `AudioSource` and `AudioSink` ABCs so the audio capture and
playback paths can be tested without an actual sound device. Real
implementations wrap `sounddevice` (lazy-imported); fake
implementations let tests script the audio stream in memory.

The API is synchronous on purpose. Asyncio integration happens at a
higher level (see `server/audio.py`) by running the blocking I/O in a
thread executor.
"""

from __future__ import annotations

import queue
import threading
from abc import ABC, abstractmethod

from .audio_packet import BYTES_PER_SAMPLE, SAMPLE_RATE_HZ, silence_payload


class AudioSource(ABC):
    """Produces PCM samples (S16_LE mono @ 16 kHz)."""

    @abstractmethod
    def start(self) -> None: ...

    @abstractmethod
    def stop(self) -> None: ...

    @abstractmethod
    def read(self, n_samples: int, timeout: float = 1.0) -> bytes:
        """Block until n_samples are available; return their byte payload.

        Returns fewer than n_samples * BYTES_PER_SAMPLE bytes on timeout
        or stream end. Returns b"" if the source is stopped.
        """


class AudioSink(ABC):
    """Consumes PCM samples (S16_LE mono @ 16 kHz)."""

    @abstractmethod
    def start(self) -> None: ...

    @abstractmethod
    def stop(self) -> None: ...

    @abstractmethod
    def write(self, samples: bytes) -> None: ...


# ---------------------------------------------------------------------------
# Fakes — fully usable without any audio hardware. Used by tests and as a
# dev-machine fallback when sounddevice can't open a real device.
# ---------------------------------------------------------------------------
class FakeAudioSource(AudioSource):
    """Replays a fixed list of byte chunks, then yields silence forever.

    Each chunk is treated as a discrete "frame" returned by one read()
    call. If a chunk's length differs from `n_samples * BYTES_PER_SAMPLE`,
    the chunk is returned as-is — the caller is expected to handle
    short reads gracefully (real sounddevice does this too).
    """

    def __init__(self, chunks: list[bytes] | None = None) -> None:
        self._chunks: list[bytes] = list(chunks) if chunks else []
        self._idx = 0
        self._started = False
        self._stopped = False
        self._lock = threading.Lock()

    def start(self) -> None:
        with self._lock:
            self._started = True
            self._stopped = False

    def stop(self) -> None:
        with self._lock:
            self._stopped = True

    def read(self, n_samples: int, timeout: float = 1.0) -> bytes:
        with self._lock:
            if self._stopped or not self._started:
                return b""
            if self._idx < len(self._chunks):
                chunk = self._chunks[self._idx]
                self._idx += 1
                return chunk
        return silence_payload(n_samples)

    @property
    def consumed(self) -> int:
        return self._idx


class FakeAudioSink(AudioSink):
    """Records every write() into an in-memory list."""

    def __init__(self) -> None:
        self.received: list[bytes] = []
        self._started = False
        self._stopped = False
        self._lock = threading.Lock()

    def start(self) -> None:
        with self._lock:
            self._started = True
            self._stopped = False

    def stop(self) -> None:
        with self._lock:
            self._stopped = True

    def write(self, samples: bytes) -> None:
        with self._lock:
            if self._stopped or not self._started:
                return
            self.received.append(samples)

    @property
    def total_bytes(self) -> int:
        return sum(len(c) for c in self.received)


# ---------------------------------------------------------------------------
# Real sounddevice implementations — lazy-imported so non-audio code can
# still import this module on machines without PortAudio installed.
# ---------------------------------------------------------------------------
def _import_sounddevice():
    """Import sounddevice only when actually needed.

    Raises ImportError with a clear hint instead of cryptic OSError on
    missing PortAudio. Test code never calls this.
    """
    try:
        import sounddevice  # type: ignore[import-not-found]
        return sounddevice
    except (ImportError, OSError) as e:
        raise ImportError(
            "sounddevice (and PortAudio) not available; "
            "install with `uv add sounddevice` and ensure libportaudio is "
            f"present on the system. Original: {e}"
        ) from e


class SoundDeviceSource(AudioSource):
    """Real mic capture via PortAudio/ALSA.

    On the Pi this binds to the I2S MEMS mic (INMP441) once the
    googlevoicehat-soundcard overlay is loaded. On a laptop it picks up
    whatever the OS exposes as the default input device.
    """

    def __init__(
        self,
        sample_rate: int = SAMPLE_RATE_HZ,
        device: int | str | None = None,
        block_samples: int = 320,  # 20 ms — small to keep latency low
    ) -> None:
        self.sample_rate = sample_rate
        self.device = device
        self.block_samples = block_samples
        self._stream = None
        self._queue: queue.Queue[bytes] = queue.Queue(maxsize=128)

    def start(self) -> None:
        sd = _import_sounddevice()

        def _callback(indata, frames, time_info, status):  # noqa: ANN001
            # status carries underrun/overrun flags from PortAudio; we
            # log via stderr but keep streaming
            if status:
                print(f"[audio_io] sounddevice input status: {status}")
            try:
                self._queue.put_nowait(bytes(indata))
            except queue.Full:
                # drop the chunk rather than block the audio callback
                pass

        self._stream = sd.RawInputStream(
            samplerate=self.sample_rate,
            channels=1,
            dtype="int16",
            blocksize=self.block_samples,
            device=self.device,
            callback=_callback,
        )
        self._stream.start()

    def stop(self) -> None:
        if self._stream is not None:
            self._stream.stop()
            self._stream.close()
            self._stream = None

    def read(self, n_samples: int, timeout: float = 1.0) -> bytes:
        # Aggregate enough chunks to satisfy n_samples (but accept short reads
        # on timeout so the caller can recover).
        target = n_samples * BYTES_PER_SAMPLE
        buf = bytearray()
        while len(buf) < target:
            try:
                chunk = self._queue.get(timeout=timeout)
            except queue.Empty:
                break
            buf.extend(chunk)
        return bytes(buf)


class SoundDeviceSink(AudioSink):
    """Real speaker output via PortAudio/ALSA."""

    def __init__(
        self,
        sample_rate: int = SAMPLE_RATE_HZ,
        device: int | str | None = None,
        block_samples: int = 320,
    ) -> None:
        self.sample_rate = sample_rate
        self.device = device
        self.block_samples = block_samples
        self._stream = None

    def start(self) -> None:
        sd = _import_sounddevice()
        self._stream = sd.RawOutputStream(
            samplerate=self.sample_rate,
            channels=1,
            dtype="int16",
            blocksize=self.block_samples,
            device=self.device,
        )
        self._stream.start()

    def stop(self) -> None:
        if self._stream is not None:
            self._stream.stop()
            self._stream.close()
            self._stream = None

    def write(self, samples: bytes) -> None:
        if self._stream is None:
            return
        # sounddevice expects bytes-like for raw streams
        self._stream.write(samples)
