"""UDP beacon broadcaster for LAN auto-discovery.

Broadcasts a JSON beacon every 2 seconds on UDP port 5555 so clients
can find the server without relying on mDNS (unreliable on Steam Deck).
"""

import json
import socket
import threading
import time

BEACON_PORT = 5555
BEACON_INTERVAL = 2.0
WS_PORT = 8765
VIDEO_PORT = 5000


def _get_local_ip() -> str:
    """Get the local IP address by connecting to a known external address."""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except OSError:
        return "127.0.0.1"


def _beacon_loop(stop_event: threading.Event):
    """Broadcast UDP beacon until stop_event is set."""
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    sock.settimeout(1.0)

    local_ip = _get_local_ip()
    payload = json.dumps({
        "name": "robothector",
        "ip": local_ip,
        "ws_port": WS_PORT,
        "video_port": VIDEO_PORT,
    }).encode()

    print(f"[discovery] broadcasting beacon on UDP {BEACON_PORT} (ip={local_ip})")

    while not stop_event.is_set():
        try:
            sock.sendto(payload, ("255.255.255.255", BEACON_PORT))
        except OSError as e:
            print(f"[discovery] broadcast error: {e}")
        stop_event.wait(BEACON_INTERVAL)

    sock.close()
    print("[discovery] beacon stopped")


_stop_event: threading.Event | None = None
_thread: threading.Thread | None = None


def start():
    """Start the beacon broadcaster in a background thread."""
    global _stop_event, _thread
    if _thread is not None and _thread.is_alive():
        return
    _stop_event = threading.Event()
    _thread = threading.Thread(target=_beacon_loop, args=(_stop_event,), daemon=True)
    _thread.start()


def stop():
    """Stop the beacon broadcaster."""
    global _stop_event, _thread
    if _stop_event is not None:
        _stop_event.set()
    if _thread is not None:
        _thread.join(timeout=5.0)
        _thread = None


if __name__ == "__main__":
    start()
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        stop()
