"""Unified server entry point.

Starts all server components: motors, sirens, camera, discovery beacon,
and the WebSocket control server.

Usage: uv run python -m server.main [--no-camera] [--no-motors]
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
    return parser.parse_args()


def main():
    args = parse_args()
    camera = None

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
    print("=" * 50)
    print("[main] ready — waiting for client")

    # WebSocket server (blocks on asyncio event loop)
    control = ControlServer(port=args.ws_port)
    asyncio.run(control.start())


if __name__ == "__main__":
    main()
