"""WebSocket control server with dead-man's switch.

Accepts one client at a time. Routes drive/mode/ping messages
to motors and sirens. Implements watchdog safety timeout.
"""

import asyncio
import json
import time

import websockets

from server import motors, sirens

WS_PORT = 8765
DEADMAN_TIMEOUT = 0.5    # seconds without message -> stop motors
SAFE_MODE_TIMEOUT = 5.0  # seconds without message -> safe mode warning
STATE_INTERVAL = 0.2     # 5Hz state broadcast


class ControlServer:
    def __init__(self, port: int = WS_PORT):
        self.port = port
        self._client = None
        self._last_message_time = 0.0
        self._safe_mode = False
        self._current_mode = ""
        self._running = False

    async def start(self):
        """Start the WebSocket server (blocks on the event loop)."""
        self._running = True
        async with websockets.serve(self._handle_client, "0.0.0.0", self.port):
            _log(f"listening on ws://0.0.0.0:{self.port}")
            watchdog = asyncio.create_task(self._watchdog())
            state_sender = asyncio.create_task(self._state_loop())
            try:
                await asyncio.Future()  # run forever
            finally:
                self._running = False
                watchdog.cancel()
                state_sender.cancel()
                _safe_stop()

    async def _handle_client(self, ws):
        """Handle a single WebSocket client connection."""
        if self._client is not None:
            _log("kicking previous client")
            try:
                await self._client.close()
            except Exception:
                pass
            self._client = None
            _safe_stop()
            sirens.stop_sirens()

        self._client = ws
        self._last_message_time = time.monotonic()
        self._safe_mode = False
        remote = ws.remote_address
        _log(f"client connected: {remote}")

        try:
            async for raw in ws:
                self._last_message_time = time.monotonic()
                self._safe_mode = False
                try:
                    msg = json.loads(raw)
                    self._dispatch(msg)
                except json.JSONDecodeError:
                    await ws.send(json.dumps({
                        "type": "error",
                        "message": "invalid JSON",
                    }))
        except websockets.ConnectionClosed:
            pass
        finally:
            self._client = None
            _safe_stop()
            sirens.stop_sirens()
            self._current_mode = ""
            _log(f"client disconnected: {remote}")

    def _dispatch(self, msg: dict):
        """Route an incoming message to the appropriate handler."""
        msg_type = msg.get("type")

        if msg_type == "drive":
            axis_x = float(msg.get("axis_x", 0))
            axis_y = float(msg.get("axis_y", 0))
            left, right = motors.arcade_mix(axis_x, axis_y)
            motors.set_motors(left, right)

        elif msg_type == "mode":
            mode = msg.get("mode", "")
            self._current_mode = mode
            sirens.play_siren(mode)

        elif msg_type == "ping":
            if self._client:
                asyncio.get_event_loop().create_task(
                    self._client.send(json.dumps({"type": "pong"}))
                )

    async def _watchdog(self):
        """Dead-man's switch: stop motors if no messages received."""
        while self._running:
            await asyncio.sleep(0.1)
            if self._client is None:
                continue
            elapsed = time.monotonic() - self._last_message_time
            if elapsed > SAFE_MODE_TIMEOUT and not self._safe_mode:
                self._safe_mode = True
                _safe_stop()
                _log("SAFE MODE: no messages for 5s")
            elif elapsed > DEADMAN_TIMEOUT:
                _safe_stop()

    async def _state_loop(self):
        """Broadcast state to connected client at 5Hz."""
        while self._running:
            await asyncio.sleep(STATE_INTERVAL)
            if self._client is not None:
                try:
                    await self._client.send(json.dumps({
                        "type": "state",
                        "mode": self._current_mode,
                        "connected": True,
                    }))
                except websockets.ConnectionClosed:
                    pass


def _safe_stop():
    """Stop motors, never raises."""
    try:
        motors.stop()
    except Exception:
        pass


def _log(msg: str):
    print(f"[control] {msg}")
