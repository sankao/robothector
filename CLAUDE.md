# CLAUDE.md

## Project Overview

Robothector is a remotely controlled robot with a client/server architecture:
- **Server (Raspberry Pi 4)**: controls dual DC motors (tank drive via L298N H-bridge), streams camera video (Pi Camera Module 3 / IMX708), UDP beacon discovery
- **Client (desktop, later Steam Deck)**: pygame app displaying live video, sending joystick commands over WebSocket

Communication: WebSocket + JSON for control (port 8765), MJPEG over HTTP for video (port 5000), UDP beacon for discovery (port 5555). See `docs/protocol.md`.

## Running

```bash
# Server (on Pi)
ssh robothector 'cd ~/robothector && uv run python -m server.main'

# Server with flags (dev/testing)
ssh robothector 'cd ~/robothector && uv run python -m server.main --no-camera --no-motors'

# Client (on desktop)
uv run python -m client.main --host 192.168.50.169 --windowed

# Motor test (on Pi, no server running)
ssh robothector 'cd ~/robothector && python3 -m server.motor_test --duration 5'
```

## Project Structure

```
server/
  __init__.py
  motors.py        # Tank drive: arcade_mix(), set_motors(), stop()
  sirens.py        # Emergency siren playback (pygame.mixer)
  camera.py        # MJPEG streaming from picamera2
  control.py       # WebSocket server + dead-man's switch
  discovery.py     # UDP beacon broadcaster
  main.py          # Unified entry point (--no-camera, --no-motors)
  motor_test.py    # Standalone GPIO motor test with countdown
  hardware_test.py # Full hardware diagnostic (motors + camera)
  __main__.py      # python -m server support
client/
  __init__.py
  joystick.py      # Gamepad input with hotplug, deadzone, mode toggles
  network.py       # WebSocket client with auto-reconnect + discovery fallback
  video.py         # MJPEG stream decoder to pygame surfaces
  discovery.py     # UDP beacon listener
  ui.py            # HUD overlay (connection status, mode, joystick indicator)
  main.py          # Pygame main loop (30fps)
  test_connection.py  # Connectivity test (mDNS, beacon, SSH, HTTP, WS)
  __main__.py      # python -m client support
docs/
  protocol.md      # WebSocket JSON message spec
  steamdeck-env.md # Steam Deck environment research
scripts/
  install-service.sh  # systemd service installer for Pi
```

## Hardware

### Pinout (L298N H-bridge, BCM numbering)

| GPIO | Pin | Function | Wire  |
|------|-----|----------|-------|
| 26   | 37  | IN1      | brown |
| 19   | 35  | IN2      | black |
| 13   | 33  | IN3      | white |
| 6    | 31  | IN4      | grey  |
| GND  | 39  | GND      | —     |

All 5 connections are consecutive on the left column of the 40-pin header (pins 31-39). **GND is required** — without it the H-bridge can't read GPIO signals.

Full GPIO header diagram in `pinout.md`.

### Power

- 2S LiPo battery (7.4V nominal) → L298N motor supply
- Pi powered separately via USB-C

### Future: I2S Audio (ordered)

- INMP441/ICS43434 I2S MEMS mic (GPIO 18/19/20)
- MAX98357A I2S 3W amp (GPIO 18/19/21)
- **GPIO 19 conflict**: shared with motor IN2, must rewire before audio

## Pi Setup

```bash
ssh robothector          # user: robothector, IP: 192.168.50.169
```

### Pi venv must use --system-site-packages

picamera2 depends on system `libcamera` which can't be pip-installed:
```bash
uv venv --system-site-packages
uv pip install websockets flask pygame RPi.GPIO picamera2
```

Also needs `libcap-dev` for python-prctl (picamera2 dependency):
```bash
sudo apt-get install -y libcap-dev
```

### Deploying code to Pi

Pi can't pull from GitHub directly. Use rsync:
```bash
rsync -avz --exclude='.venv' --exclude='__pycache__' --exclude='.beads' . robothector:~/robothector/
```

### Running server persistently

```bash
ssh robothector 'export PATH="$HOME/.local/bin:$PATH" && cd ~/robothector && nohup uv run python -m server.main > /tmp/robothector.log 2>&1 &'
```

Use `python3 -u` for unbuffered output when debugging over SSH.

## Notes

- Use `uv` for dependency management
- Use `bd` for task tracking (`bd ready`, `bd list --pretty`)
- Prototype on desktop first, Steam Deck later
- No test suite or CI/CD configured
- Git remote: `git@github.com:sankao/robothector.git`, branch: `master`
- Kill server before running motor_test.py (both use same GPIO pins)
- When killing client, restart server too — zombie WebSocket connections block reconnects
