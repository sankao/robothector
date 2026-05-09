"""Unified server entry point.

Starts all server components: motors, sirens, camera, discovery beacon,
audio plane, and the WebSocket control server.

Usage: uv run python -m server.main [--no-camera] [--no-motors] [--no-audio]
"""

import argparse
import asyncio
import signal
import sys

from server import motors, sirens
from server.camera import CameraServer
from server.control import ControlServer
from server.discovery import start as beacon_start, stop as beacon_stop


def parse_args():
    parser = argparse.ArgumentParser(description="Robothector server")
    parser.add_argument("--ws-port", type=int, default=8765, help="WebSocket port")
    parser.add_argument("--video-port", type=int, default=5000, help="MJPEG video port")
    parser.add_argument("--no-camera", action="store_true", help="Skip camera init")
    parser.add_argument("--no-motors", action="store_true", help="Skip GPIO motor init")
    parser.add_argument("--no-audio", action="store_true",
                        help="Skip audio plane (mic/amp). Use on Pi until I2S is wired.")
    return parser.parse_args()


def _make_audio_server():
    """Build an AudioServer. Falls back to fakes if sounddevice can't open
    a device — that's the expected state on a Pi before the I2S overlay
    is enabled. Returns None on hard failure (server keeps running)."""
    from protocol.audio_io import (
        FakeAudioSink,
        FakeAudioSource,
        SoundDeviceSink,
        SoundDeviceSource,
    )
    from server.audio import AudioServer

    try:
        source = SoundDeviceSource()
        sink = SoundDeviceSink()
        # Probe by starting+stopping the sink — surfaces "no I2S overlay" early
        sink.start()
        sink.stop()
        print("[main] audio: real sounddevice (I2S mic + amp)")
    except Exception as e:
        print(f"[main] audio: sounddevice unavailable ({e}); using fakes "
              f"— audio messages will be acknowledged but no PCM will flow")
        source = FakeAudioSource()
        sink = FakeAudioSink()

    try:
        return AudioServer(source=source, sink=sink)
    except OSError as e:
        # bind failure on UDP port — port already in use, etc.
        print(f"[main] audio: failed to bind UDP sockets ({e}); audio disabled")
        return None


def main():
    args = parse_args()
    camera = None
    audio = None

    print("=" * 50)
    print("Robothector Server")
    print("=" * 50)

    # Motors
    if args.no_motors:
        print("[main] motors: SKIPPED (--no-motors)")
    else:
        motors.init()

    # Sirens
    sirens.init()

    # Camera
    if args.no_camera:
        print("[main] camera: SKIPPED (--no-camera)")
    else:
        camera = CameraServer()
        camera.start(port=args.video_port)

    # Audio
    if args.no_audio:
        print("[main] audio: SKIPPED (--no-audio)")
    else:
        audio = _make_audio_server()

    # Discovery beacon
    beacon_start()

    # Signal handling
    def _shutdown(sig, frame):
        print(f"\n[main] received signal {sig}, shutting down...")
        try:
            motors.stop()
        except Exception:
            pass
        motors.cleanup()
        if camera:
            camera.stop()
        if audio:
            audio.shutdown()
        sirens.cleanup()
        beacon_stop()
        print("[main] shutdown complete")
        sys.exit(0)

    signal.signal(signal.SIGTERM, _shutdown)
    signal.signal(signal.SIGINT, _shutdown)

    from server.discovery import _get_local_ip
    ip = _get_local_ip()
    print(f"[main] IP: {ip}")
    print(f"[main] WebSocket: ws://{ip}:{args.ws_port}")
    print(f"[main] Video: http://{ip}:{args.video_port}/video_feed")
    print(f"[main] GPIO: {'available' if motors._has_gpio else 'stub'}")
    print(f"[main] Audio: {'enabled' if audio is not None else 'disabled'}")
    print("=" * 50)
    print("[main] ready — waiting for client")

    # WebSocket server (blocks on asyncio event loop)
    control = ControlServer(port=args.ws_port, audio_server=audio)
    asyncio.run(control.start())


if __name__ == "__main__":
    main()
