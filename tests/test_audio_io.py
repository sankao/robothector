"""Tests for protocol.audio_io fakes (real sounddevice impls smoke-tested manually)."""

from __future__ import annotations

import pytest

from protocol.audio_io import FakeAudioSink, FakeAudioSource
from protocol.audio_packet import BYTES_PER_SAMPLE, silence_payload


def chunk(n_samples: int, fill: int = 0) -> bytes:
    return (fill.to_bytes(2, "little", signed=True)) * n_samples


class TestFakeAudioSource:
    def test_returns_silence_when_chunks_exhausted(self) -> None:
        src = FakeAudioSource(chunks=[chunk(320, fill=1)])
        src.start()
        first = src.read(320)
        assert first == chunk(320, fill=1)
        # exhausted -> silence
        second = src.read(320)
        assert second == silence_payload(320)
        third = src.read(320)
        assert third == silence_payload(320)

    def test_replays_chunks_in_order(self) -> None:
        chunks = [chunk(320, fill=i) for i in range(5)]
        src = FakeAudioSource(chunks=chunks)
        src.start()
        for i in range(5):
            assert src.read(320) == chunk(320, fill=i)

    def test_no_chunks_yields_silence(self) -> None:
        src = FakeAudioSource()
        src.start()
        assert src.read(320) == silence_payload(320)

    def test_returns_empty_when_not_started(self) -> None:
        src = FakeAudioSource(chunks=[chunk(320)])
        assert src.read(320) == b""

    def test_returns_empty_after_stop(self) -> None:
        src = FakeAudioSource(chunks=[chunk(320)])
        src.start()
        src.stop()
        assert src.read(320) == b""

    def test_consumed_count(self) -> None:
        src = FakeAudioSource(chunks=[chunk(320), chunk(320), chunk(320)])
        src.start()
        src.read(320)
        src.read(320)
        assert src.consumed == 2

    def test_restart_resets_stopped_flag(self) -> None:
        src = FakeAudioSource(chunks=[chunk(320, fill=7)])
        src.start()
        src.stop()
        src.start()
        assert src.read(320) == chunk(320, fill=7)


class TestFakeAudioSink:
    def test_records_writes_in_order(self) -> None:
        sink = FakeAudioSink()
        sink.start()
        sink.write(chunk(320, fill=1))
        sink.write(chunk(320, fill=2))
        assert sink.received == [chunk(320, fill=1), chunk(320, fill=2)]

    def test_total_bytes_tracks_writes(self) -> None:
        sink = FakeAudioSink()
        sink.start()
        sink.write(chunk(320))
        sink.write(chunk(640))
        assert sink.total_bytes == (320 + 640) * BYTES_PER_SAMPLE

    def test_writes_dropped_when_not_started(self) -> None:
        sink = FakeAudioSink()
        sink.write(chunk(320))
        assert sink.received == []

    def test_writes_dropped_after_stop(self) -> None:
        sink = FakeAudioSink()
        sink.start()
        sink.write(chunk(320))
        sink.stop()
        sink.write(chunk(320))
        assert len(sink.received) == 1


class TestSoundDeviceLazyImport:
    """Real impls are lazy — instantiation must not require sounddevice
    installed; only start() does."""

    def test_can_construct_without_sounddevice(self) -> None:
        from protocol.audio_io import SoundDeviceSink, SoundDeviceSource
        # constructor must succeed even on a system with no PortAudio
        SoundDeviceSource()
        SoundDeviceSink()
        # if this raises, it's an import-time regression


class TestSoundDeviceMissingDeps:
    """If sounddevice is not installed (CI / dev laptop without audio),
    start() must raise ImportError with a clear message — not a crash."""

    def test_start_raises_clear_error_when_sounddevice_missing(
        self, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        # Simulate a system without sounddevice by monkeypatching the
        # private import helper.
        from protocol import audio_io

        def _fake_import():
            raise ImportError("sounddevice (and PortAudio) not available; ...")

        monkeypatch.setattr(audio_io, "_import_sounddevice", _fake_import)
        src = audio_io.SoundDeviceSource()
        with pytest.raises(ImportError, match="sounddevice"):
            src.start()
