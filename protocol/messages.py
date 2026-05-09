"""WebSocket JSON message types.

All client->server and server->client messages on port 8765 are typed
through dataclasses defined here. Audio PCM travels separately over UDP
(see protocol.audio_packet); WS only carries the *control* plane for
audio (start/stop listening, push-to-talk state).

Wire format: each message is a JSON object with a "type" discriminator
plus per-message fields. Unknown extra fields are ignored on parse so
old clients can talk to new servers and vice versa.
"""

from __future__ import annotations

import json
from dataclasses import asdict, dataclass, field
from typing import Literal, Union

# ---- valid mode values ------------------------------------------------------
Mode = Literal["", "firefighter", "ambulance"]
VALID_MODES: frozenset[str] = frozenset({"", "firefighter", "ambulance"})


# ---- client -> server -------------------------------------------------------
@dataclass(frozen=True)
class DriveMessage:
    axis_x: float = 0.0
    axis_y: float = 0.0
    type: Literal["drive"] = "drive"

    def __post_init__(self) -> None:
        if not -1.0 <= self.axis_x <= 1.0:
            raise ValueError(f"drive.axis_x out of [-1, 1]: {self.axis_x}")
        if not -1.0 <= self.axis_y <= 1.0:
            raise ValueError(f"drive.axis_y out of [-1, 1]: {self.axis_y}")


@dataclass(frozen=True)
class ModeMessage:
    mode: str = ""
    type: Literal["mode"] = "mode"

    def __post_init__(self) -> None:
        if self.mode not in VALID_MODES:
            raise ValueError(
                f"mode.mode {self.mode!r} not in {sorted(VALID_MODES)}"
            )


@dataclass(frozen=True)
class PingMessage:
    type: Literal["ping"] = "ping"


@dataclass(frozen=True)
class AudioListenMessage:
    """Client requests the server start (or stop) streaming mic audio.

    When enabled, server opens its INMP441 capture and sends PCM packets
    via UDP to the client's listening port. When disabled, the capture
    thread idles and no UDP packets are emitted.
    """

    enabled: bool = False
    type: Literal["audio_listen"] = "audio_listen"


@dataclass(frozen=True)
class AudioTalkMessage:
    """Client tells server it is now sending mic audio (push-to-talk).

    Server uses this as a hint to start listening on its UDP audio-in
    port and pump received PCM through to the MAX98357A amp. When
    disabled, server stops playback (drops to silence cleanly).
    """

    enabled: bool = False
    type: Literal["audio_talk"] = "audio_talk"


ClientMessage = Union[
    DriveMessage,
    ModeMessage,
    PingMessage,
    AudioListenMessage,
    AudioTalkMessage,
]


# ---- server -> client -------------------------------------------------------
@dataclass(frozen=True)
class StateMessage:
    mode: str = ""
    connected: bool = False
    audio_listen: bool = False
    audio_talk: bool = False
    type: Literal["state"] = "state"


@dataclass(frozen=True)
class PongMessage:
    type: Literal["pong"] = "pong"


@dataclass(frozen=True)
class ErrorMessage:
    message: str = ""
    type: Literal["error"] = "error"


ServerMessage = Union[StateMessage, PongMessage, ErrorMessage]


# ---- parser / serialiser ----------------------------------------------------
_CLIENT_PARSERS = {
    "drive": lambda d: DriveMessage(
        axis_x=float(d.get("axis_x", 0.0)),
        axis_y=float(d.get("axis_y", 0.0)),
    ),
    "mode": lambda d: ModeMessage(mode=str(d.get("mode", ""))),
    "ping": lambda d: PingMessage(),
    "audio_listen": lambda d: AudioListenMessage(
        enabled=bool(d.get("enabled", False))
    ),
    "audio_talk": lambda d: AudioTalkMessage(
        enabled=bool(d.get("enabled", False))
    ),
}


def parse_client_message(raw: str) -> ClientMessage:
    """Parse a JSON-encoded WS frame from the client.

    Raises ValueError on bad JSON, missing 'type', unknown type, or any
    field validation failure (e.g. drive axis out of range).
    """
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as e:
        raise ValueError(f"invalid JSON: {e}") from e
    if not isinstance(data, dict):
        raise ValueError(f"expected JSON object, got {type(data).__name__}")
    msg_type = data.get("type")
    if msg_type is None:
        raise ValueError("message missing required 'type' field")
    parser = _CLIENT_PARSERS.get(msg_type)
    if parser is None:
        raise ValueError(f"unknown client message type: {msg_type!r}")
    return parser(data)


def serialize(msg: ClientMessage | ServerMessage) -> str:
    """Encode a message as JSON for sending over the WebSocket."""
    return json.dumps(asdict(msg))
