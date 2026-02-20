"""Connection test script — verify all connectivity before a driving session.

Usage: uv run python -m client.test_connection
"""

import socket
import subprocess
import sys
import time
import urllib.request

DEFAULT_HOST = "192.168.50.169"
WS_PORT = 8765
VIDEO_PORT = 5000


def test_mdns() -> tuple[bool, str]:
    """Test mDNS resolution of robothector.local."""
    start = time.monotonic()
    try:
        results = socket.getaddrinfo("robothector.local", None)
        elapsed = (time.monotonic() - start) * 1000
        ip = results[0][4][0]
        return True, f"resolved to {ip} ({elapsed:.0f}ms)"
    except socket.gaierror as e:
        elapsed = (time.monotonic() - start) * 1000
        return False, f"{e} ({elapsed:.0f}ms)"


def test_udp_beacon() -> tuple[bool, str]:
    """Listen for UDP beacon from server."""
    start = time.monotonic()
    try:
        from client.discovery import discover
        result = discover(timeout=5.0)
        elapsed = (time.monotonic() - start) * 1000
        if result:
            ip, ws_port, video_port = result
            return True, f"found at {ip} ws={ws_port} video={video_port} ({elapsed:.0f}ms)"
        return False, f"no beacon received ({elapsed:.0f}ms)"
    except Exception as e:
        elapsed = (time.monotonic() - start) * 1000
        return False, f"{e} ({elapsed:.0f}ms)"


def test_ssh() -> tuple[bool, str]:
    """Test SSH connectivity to Pi."""
    start = time.monotonic()
    try:
        result = subprocess.run(
            ["ssh", "-o", "ConnectTimeout=3", "-o", "BatchMode=yes",
             "robothector", "echo ok"],
            capture_output=True, text=True, timeout=10,
        )
        elapsed = (time.monotonic() - start) * 1000
        if result.returncode == 0 and "ok" in result.stdout:
            return True, f"connected ({elapsed:.0f}ms)"
        return False, f"exit={result.returncode} ({elapsed:.0f}ms)"
    except subprocess.TimeoutExpired:
        elapsed = (time.monotonic() - start) * 1000
        return False, f"timeout ({elapsed:.0f}ms)"
    except FileNotFoundError:
        return False, "ssh not found"


def test_http_video(host: str) -> tuple[bool, str]:
    """Test HTTP video endpoint."""
    start = time.monotonic()
    url = f"http://{host}:{VIDEO_PORT}/health"
    try:
        resp = urllib.request.urlopen(url, timeout=3)
        elapsed = (time.monotonic() - start) * 1000
        return True, f"HTTP {resp.status} ({elapsed:.0f}ms)"
    except Exception as e:
        elapsed = (time.monotonic() - start) * 1000
        return False, f"{e} ({elapsed:.0f}ms)"


def test_websocket(host: str) -> tuple[bool, str]:
    """Test WebSocket connectivity."""
    start = time.monotonic()
    try:
        import websocket
        ws = websocket.create_connection(f"ws://{host}:{WS_PORT}", timeout=3)
        ws.close()
        elapsed = (time.monotonic() - start) * 1000
        return True, f"connected ({elapsed:.0f}ms)"
    except ImportError:
        return False, "websocket-client not installed"
    except Exception as e:
        elapsed = (time.monotonic() - start) * 1000
        return False, f"{e} ({elapsed:.0f}ms)"


def main():
    print("Robothector Connection Test")
    print("=" * 50)

    host = DEFAULT_HOST
    all_pass = True

    tests = [
        ("mDNS", test_mdns, False),          # not critical
        ("UDP beacon", test_udp_beacon, False),  # not critical
        ("SSH", test_ssh, True),              # critical
        ("HTTP video", lambda: test_http_video(host), False),
        ("WebSocket", lambda: test_websocket(host), False),
    ]

    for name, test_fn, critical in tests:
        passed, detail = test_fn()
        status = "PASS" if passed else "FAIL"
        marker = " [critical]" if critical and not passed else ""
        print(f"  {status}: {name} — {detail}{marker}")
        if critical and not passed:
            all_pass = False

    print("=" * 50)
    if all_pass:
        print("All critical tests passed.")
    else:
        print("Some critical tests FAILED.")
    sys.exit(0 if all_pass else 1)


if __name__ == "__main__":
    main()
