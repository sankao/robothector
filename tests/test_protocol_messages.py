"""Tests for protocol.messages — WebSocket control plane."""

from __future__ import annotations

import json

import pytest

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


# ---- DriveMessage ----------------------------------------------------------
class TestDriveMessage:
    def test_default_is_centered(self) -> None:
        msg = DriveMessage()
        assert msg.axis_x == 0.0
        assert msg.axis_y == 0.0
        assert msg.type == "drive"

    def test_round_trip(self) -> None:
        original = DriveMessage(axis_x=0.5, axis_y=-0.7)
        parsed = parse_client_message(serialize(original))
        assert parsed == original

    @pytest.mark.parametrize("bad", [-1.5, 1.001, 2.0, -2.0, float("inf")])
    def test_rejects_axis_x_out_of_range(self, bad: float) -> None:
        with pytest.raises(ValueError, match="axis_x"):
            DriveMessage(axis_x=bad, axis_y=0.0)

    @pytest.mark.parametrize("bad", [-1.5, 1.001, 2.0, -2.0, float("inf")])
    def test_rejects_axis_y_out_of_range(self, bad: float) -> None:
        with pytest.raises(ValueError, match="axis_y"):
            DriveMessage(axis_x=0.0, axis_y=bad)

    @pytest.mark.parametrize("good", [-1.0, -0.999, -0.5, 0.0, 0.5, 0.999, 1.0])
    def test_accepts_axis_at_and_inside_bounds(self, good: float) -> None:
        DriveMessage(axis_x=good, axis_y=good)  # no raise

    def test_parse_with_missing_fields_uses_defaults(self) -> None:
        msg = parse_client_message('{"type": "drive"}')
        assert msg == DriveMessage()

    def test_parse_with_axis_out_of_range_raises(self) -> None:
        with pytest.raises(ValueError):
            parse_client_message('{"type": "drive", "axis_x": 5}')


# ---- ModeMessage -----------------------------------------------------------
class TestModeMessage:
    @pytest.mark.parametrize("mode", ["", "firefighter", "ambulance"])
    def test_accepts_valid_modes(self, mode: str) -> None:
        msg = ModeMessage(mode=mode)
        assert msg.mode == mode

    def test_rejects_unknown_mode(self) -> None:
        with pytest.raises(ValueError, match="not in"):
            ModeMessage(mode="bulldozer")

    def test_round_trip(self) -> None:
        original = ModeMessage(mode="firefighter")
        assert parse_client_message(serialize(original)) == original


# ---- AudioListenMessage / AudioTalkMessage --------------------------------
class TestAudioMessages:
    def test_audio_listen_default_disabled(self) -> None:
        msg = parse_client_message('{"type": "audio_listen"}')
        assert msg == AudioListenMessage(enabled=False)

    def test_audio_listen_enabled(self) -> None:
        msg = parse_client_message('{"type": "audio_listen", "enabled": true}')
        assert msg == AudioListenMessage(enabled=True)

    def test_audio_talk_round_trip(self) -> None:
        original = AudioTalkMessage(enabled=True)
        assert parse_client_message(serialize(original)) == original

    def test_audio_listen_truthy_int_coerces_to_bool(self) -> None:
        # Some clients send 1/0 instead of true/false
        msg = parse_client_message('{"type": "audio_listen", "enabled": 1}')
        assert msg.enabled is True


# ---- PingMessage -----------------------------------------------------------
class TestPing:
    def test_round_trip(self) -> None:
        assert parse_client_message(serialize(PingMessage())) == PingMessage()


# ---- parse_client_message error paths --------------------------------------
class TestParserErrors:
    def test_invalid_json(self) -> None:
        with pytest.raises(ValueError, match="invalid JSON"):
            parse_client_message("not json")

    def test_non_object_json(self) -> None:
        with pytest.raises(ValueError, match="expected JSON object"):
            parse_client_message("[1, 2, 3]")

    def test_missing_type(self) -> None:
        with pytest.raises(ValueError, match="missing required 'type'"):
            parse_client_message('{"axis_x": 0.5}')

    def test_unknown_type(self) -> None:
        with pytest.raises(ValueError, match="unknown client message type"):
            parse_client_message('{"type": "selfdestruct"}')

    def test_extra_fields_are_ignored(self) -> None:
        """Forward-compat: a newer client adding fields shouldn't break old servers."""
        msg = parse_client_message(
            '{"type": "drive", "axis_x": 0.1, "axis_y": 0.2, "future_field": 99}'
        )
        assert msg == DriveMessage(axis_x=0.1, axis_y=0.2)


# ---- server messages -------------------------------------------------------
class TestServerMessages:
    def test_state_default(self) -> None:
        msg = StateMessage()
        assert msg.mode == ""
        assert msg.connected is False
        assert msg.audio_listen is False
        assert msg.audio_talk is False

    def test_state_serialize_includes_audio_fields(self) -> None:
        msg = StateMessage(
            mode="firefighter",
            connected=True,
            audio_listen=True,
            audio_talk=False,
        )
        wire = serialize(msg)
        decoded = json.loads(wire)
        assert decoded == {
            "mode": "firefighter",
            "connected": True,
            "audio_listen": True,
            "audio_talk": False,
            "type": "state",
        }

    def test_pong_serialize(self) -> None:
        assert json.loads(serialize(PongMessage())) == {"type": "pong"}

    def test_error_serialize(self) -> None:
        wire = serialize(ErrorMessage(message="kaboom"))
        assert json.loads(wire) == {"message": "kaboom", "type": "error"}
