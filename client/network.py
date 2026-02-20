"""WebSocket client for sending commands and receiving state.

Runs a background thread with auto-reconnect. Thread-safe for use
from the pygame main loop.
"""

import json
import queue
import threading
import time

import websocket


class NetworkClient:
    def __init__(self, host: str = "robothector.local", ws_port: int = 8765):
        self._host = host
        self._ws_port = ws_port
        self._ws = None
        self._thread = None
        self._running = False
        self._connected = False
        self._send_queue = queue.Queue(maxsize=100)
        self._state = None
        self._state_lock = threading.Lock()

    def start(self):
        """Start the background network thread."""
        self._running = True
        self._thread = threading.Thread(target=self._run_loop, daemon=True)
        self._thread.start()

    def stop(self):
        """Stop the background thread and close connection."""
        self._running = False
        if self._ws is not None:
            try:
                self._ws.close()
            except Exception:
                pass
        if self._thread is not None:
            self._thread.join(timeout=5.0)

    def send_drive(self, axis_x: float, axis_y: float):
        """Queue a drive command."""
        self._enqueue({"type": "drive", "axis_x": axis_x, "axis_y": axis_y})

    def send_mode(self, mode: str):
        """Queue a mode command."""
        self._enqueue({"type": "mode", "mode": mode})

    def get_state(self) -> dict | None:
        """Get the latest state from the server."""
        with self._state_lock:
            return self._state

    def is_connected(self) -> bool:
        return self._connected

    def _enqueue(self, msg: dict):
        try:
            self._send_queue.put_nowait(msg)
        except queue.Full:
            # Drop oldest to keep up
            try:
                self._send_queue.get_nowait()
            except queue.Empty:
                pass
            self._send_queue.put_nowait(msg)

    def _run_loop(self):
        """Main network loop: connect, send/receive, reconnect on failure."""
        while self._running:
            if not self._connect():
                time.sleep(2.0)
                continue

            try:
                self._ws.settimeout(0.05)  # 50ms poll
                while self._running:
                    # Send queued messages
                    while not self._send_queue.empty():
                        try:
                            msg = self._send_queue.get_nowait()
                            self._ws.send(json.dumps(msg))
                        except queue.Empty:
                            break

                    # Receive state
                    try:
                        raw = self._ws.recv()
                        if raw:
                            data = json.loads(raw)
                            if data.get("type") == "state":
                                with self._state_lock:
                                    self._state = data
                    except websocket.WebSocketTimeoutException:
                        pass

            except (websocket.WebSocketException, OSError) as e:
                _log(f"connection lost: {e}")
            finally:
                self._connected = False
                try:
                    self._ws.close()
                except Exception:
                    pass
                self._ws = None
                if self._running:
                    _log("reconnecting in 2s...")
                    time.sleep(2.0)

    def _connect(self) -> bool:
        """Try to connect, with discovery fallback."""
        url = f"ws://{self._host}:{self._ws_port}"
        try:
            _log(f"connecting to {url}...")
            self._ws = websocket.create_connection(url, timeout=3)
            self._connected = True
            _log("connected")
            return True
        except Exception:
            pass

        # Fallback: UDP beacon discovery
        try:
            from client.discovery import discover
            result = discover(timeout=5.0)
            if result:
                ip, ws_port, _ = result
                url = f"ws://{ip}:{ws_port}"
                _log(f"discovered server, connecting to {url}...")
                self._ws = websocket.create_connection(url, timeout=3)
                self._connected = True
                self._host = ip
                self._ws_port = ws_port
                _log("connected via discovery")
                return True
        except Exception:
            pass

        _log("connection failed")
        return False


def _log(msg: str):
    print(f"[network] {msg}")
