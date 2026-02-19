# CLAUDE.md

## Project Overview

Robothector is a remotely controlled robot with a client/server architecture:
- **Server (Raspberry Pi 4)**: systemd service controlling dual DC motors (tank drive via L298N H-bridge), streaming camera video (Pi Camera Module 3 / IMX708)
- **Client (desktop, later Steam Deck)**: pygame app displaying live video and sending joystick commands

Communication: WebSocket + JSON for control (port 8765), MJPEG over HTTP for video (port 5000). See `docs/protocol.md`.

## Running

```bash
# Install dependencies (desktop/client)
uv pip install pygame websocket-client flask websockets --python .venv/bin/python

# Server (on Pi)
uv run python -m server.main

# Client (on desktop)
uv run python -m client.main
```

## Project Structure

```
server/
  __init__.py
  motors.py      # Tank drive: arcade_mix(), set_motors(), stop()
  sirens.py      # Emergency siren playback (pygame.mixer)
  camera.py      # MJPEG streaming from picamera2 (TODO)
  control.py     # WebSocket server + dead-man's switch (TODO)
  main.py        # Unified entry point (TODO)
client/
  __init__.py
  joystick.py    # Steam Deck / gamepad input (TODO)
  network.py     # WebSocket client (TODO)
  video.py       # MJPEG stream display (TODO)
  main.py        # Pygame main loop + HUD (TODO)
docs/
  protocol.md    # WebSocket JSON message spec
  steamdeck-env.md  # Steam Deck environment research
```

## Hardware Pinout (L298N H-bridge, BCM numbering)

| GPIO | Pin | Function | Wire  |
|------|-----|----------|-------|
| 26   | 37  | IN1      | brown |
| 19   | 35  | IN2      | black |
| 13   | 33  | IN3      | white |
| 6    | 31  | IN4      | grey  |

Tank drive, no servo. Arcade mixing in `server/motors.py`.

## Pi Access

```bash
ssh robothector          # user: robothector, IP: 192.168.50.169
```

Pi Camera Module 3 (IMX708) verified working. GPIO pins not yet tested (H-bridge disconnected).

## Notes

- Use `uv` for dependency management
- Use `bd` for task tracking (`bd ready`, `bd list --pretty`)
- Prototype on desktop first, Steam Deck later
- No test suite or CI/CD configured
- Git remote: `git@github.com:sankao/robothector.git`, branch: `master`
