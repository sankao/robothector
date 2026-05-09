"""WebSocket control server with dead-man's switch.

Accepts one client at a time. Routes typed messages (see
`protocol.messages`) to motors / sirens / audio subsystems. Implements
the watchdog safety timeout.
"""

import asyncio
import time

import websockets

from protocol import (
    AudioListenMessage,
    AudioTalkMessage,
    DriveMessage,
    ErrorMessage,
    ModeMessage,
    PingMessage,
    PongMessage,
    StateMessage,
    parse_client_message,
    serialize,
)
from server import motors, sirens

WS_PORT = 8765
DEADMAN_TIMEOUT = 0.5    # seconds without message -> stop motors
SAFE_MODE_TIMEOUT = 5.0  # seconds without message -> safe mode warning
STATE_INTERVAL = 0.2     # 5Hz state broadcast


class ControlServer:
    def __init__(self, port: int = WS_PORT, audio_server=None):
        self.port = port
        self._client = None
        self._last_message_time = 0.0
        self._safe_mode = False
        self._current_mode = ""
        self._audio_listen = False
        self._audio_talk = False
        self._audio_server = audio_server  # optional, may be None during dev
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
                    msg = parse_client_message(raw)
                except ValueError as e:
                    await ws.send(serialize(ErrorMessage(message=str(e))))
                    continue
                await self._dispatch(msg, ws)
        except websockets.ConnectionClosed:
            pass
        finally:
            self._client = None
            _safe_stop()
            sirens.stop_sirens()
            self._audio_listen = False
            self._audio_talk = False
            if self._audio_server is not None:
                try:
                    self._audio_server.disable_listen()
                    self._audio_server.disable_talk()
                except Exception:
                    pass
            self._current_mode = ""
            _log(f"client disconnected: {remote}")

    async def _dispatch(self, msg, ws) -> None:
        """Route an already-parsed and validated typed message."""
        if isinstance(msg, DriveMessage):
            left, right = motors.arcade_mix(msg.axis_x, msg.axis_y)
            motors.set_motors(left, right)

        elif isinstance(msg, ModeMessage):
            self._current_mode = msg.mode
            sirens.play_siren(msg.mode)

        elif isinstance(msg, PingMessage):
            await ws.send(serialize(PongMessage()))

        elif isinstance(msg, AudioListenMessage):
            self._audio_listen = msg.enabled
            if self._audio_server is not None:
                try:
                    if msg.enabled:
                        # client_addr derived from WS connection; UDP target port 5556
                        client_host = ws.remote_address[0] if ws.remote_address else None
                        if client_host:
                            self._audio_server.enable_listen(client_host)
                    else:
                        self._audio_server.disable_listen()
                except Exception as e:
                    _log(f"audio_listen error: {e}")
                    await ws.send(serialize(ErrorMessage(message=str(e))))

        elif isinstance(msg, AudioTalkMessage):
            self._audio_talk = msg.enabled
            if self._audio_server is not None:
                try:
                    if msg.enabled:
                        self._audio_server.enable_talk()
                    else:
                        self._audio_server.disable_talk()
                except Exception as e:
                    _log(f"audio_talk error: {e}")
                    await ws.send(serialize(ErrorMessage(message=str(e))))

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
                    state = StateMessage(
                        mode=self._current_mode,
                        connected=True,
                        audio_listen=self._audio_listen,
                        audio_talk=self._audio_talk,
                    )
                    await self._client.send(serialize(state))
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
