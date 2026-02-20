"""UDP beacon listener for LAN auto-discovery.

Listens for the server's UDP beacon and returns connection info.
Used as fallback when robothector.local mDNS doesn't resolve.
"""

import json
import socket

BEACON_PORT = 5555
DEFAULT_TIMEOUT = 5.0


def discover(timeout: float = DEFAULT_TIMEOUT) -> tuple[str, int, int] | None:
    """Listen for a server beacon and return connection info.

    Args:
        timeout: Seconds to wait before giving up.

    Returns:
        (ip, ws_port, video_port) tuple, or None if no beacon found.
    """
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.settimeout(timeout)
    sock.bind(("", BEACON_PORT))

    try:
        data, addr = sock.recvfrom(1024)
        beacon = json.loads(data.decode())
        ip = beacon["ip"]
        ws_port = beacon["ws_port"]
        video_port = beacon["video_port"]
        print(f"[discovery] found server: {ip} (ws={ws_port}, video={video_port})")
        return ip, ws_port, video_port
    except socket.timeout:
        print("[discovery] no beacon received within timeout")
        return None
    except (json.JSONDecodeError, KeyError) as e:
        print(f"[discovery] invalid beacon: {e}")
        return None
    finally:
        sock.close()


if __name__ == "__main__":
    result = discover()
    if result:
        ip, ws_port, video_port = result
        print(f"Server at {ip} — ws://:{ws_port}  http://:{video_port}")
    else:
        print("No server found.")
