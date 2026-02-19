# Robothector - Project Status

## What Is It

Robothector is a Raspberry Pi-powered robot vehicle with emergency response themes (firefighter/ambulance). It's being upgraded from a local joystick-controlled prototype into a remotely operated robot controlled from a Steam Deck over WiFi, with live camera feed and (eventually) two-way audio.

## Current Hardware

| Component | Details |
|-----------|---------|
| Brain | Raspberry Pi (mounted inside the robot chassis) |
| Motors | 2x DC motors via L298N H-bridge — tank drive (no servo) |
| Camera | Pi Camera Module (ribbon cable) |
| Audio | 3x WAV files for sirens (firefighter, ambulance, reverse) |
| Buttons | 2x physical GPIO buttons for mode selection (firefighter/ambulance) |
| Display | 800x480 screen (currently unused in new architecture) |

### GPIO Pinout (L298N H-bridge)

From `pinout.md` — most recent documentation, includes wire colors. **Needs verification over SSH** as code files use different (older) pin assignments.

| Wire | GPIO (BCM) | Board Pin | L298N Function |
|------|------------|-----------|----------------|
| brown | 26 | 37 | IN1 |
| black | 19 | 35 | IN2 |
| white | 13 | 33 | IN3 |
| grey | 6 | 31 | IN4 |

**Known issue**: `joystick.py` and `joystick_test.py` reference BOARD pins 11/13/15/16 (BCM 17/27/22/23) — completely different physical pins. The robot was likely rewired after the code was written. The pinout must be verified before any motor code is trusted.

## Current Software State

The codebase is a working prototype — monolithic, single-machine, directly-connected-joystick only.

### Files

| File | Purpose | Status |
|------|---------|--------|
| `joystick.py` (312 lines) | Main control loop: reads joystick, drives motors, plays sirens, renders display | Legacy — will be decomposed |
| `webapp/app.py` (83 lines) | Flask server streaming MJPEG from Pi camera on port 5000 | Working, has a try/finally syntax bug |
| `joystick_test.py` | H-bridge motor test (forward/backward/stop loop) | Legacy test script |
| `angle.py` | RPi.GPIO servo PWM test | Obsolete (no servo in current build) |
| `angle_pigpio.py` | pigpio servo PWM test | Obsolete (no servo in current build) |
| `pinout.md` | Hardware pin reference | Needs verification |
| Assets | 6 PNG images, 3 WAV sirens, L298N datasheet, GPIO diagram | Carried forward |

### What Works Today

- Joystick reads and motor control (with a directly connected joystick + display)
- Camera MJPEG streaming to a web browser at `http://<pi-ip>:5000`
- Emergency mode toggling (firefighter/ambulance) with sirens
- Graceful fallback when RPi.GPIO isn't available (development on non-Pi machines)

### What Doesn't Exist Yet

- No client/server architecture
- No remote control capability
- No Steam Deck integration
- No systemd service
- No network auto-discovery
- No safety mechanisms (dead-man's switch)
- No test suite, linter, or CI/CD

## Target Architecture

```
Steam Deck (Client)                    Raspberry Pi (Server)
+--------------------------+           +---------------------------+
|  Pygame Application      |           |  systemd service          |
|                          |  WiFi     |                           |
|  Left Stick (arcade) ----+--WS:8765->|  WebSocket server         |
|    Y = throttle          |           |    -> arcade mix          |
|    X = turn              |           |    -> motors.set_motors() |
|                          |           |    -> dead-man's switch   |
|  Video Display <---------+-HTTP:5000-|  Flask MJPEG camera       |
|    640x480 MJPEG         |           |    640x480 from picamera2 |
|                          |           |                           |
|  [Future] Mic/Speaker <--+-UDP:5001--+  [Future] Mic/Speaker     |
|                     -----+-UDP:5002->|                           |
|                          |           |                           |
|  Mode buttons (L1/R1)    |           |  Sirens (local playback)  |
|  HUD overlay             |           |  GPIO → L298N → Motors    |
+--------------------------+           +---------------------------+
```

### Key Design Decisions

- **Tank drive with arcade mixing**: Single left stick. Y = throttle (both motors equally), X = turn (differential: left = throttle+turn, right = throttle-turn)
- **WebSocket + JSON for control**: Low-latency bidirectional on port 8765. Messages at ~20Hz.
- **MJPEG over HTTP for video**: Keeps the existing Flask approach. Simple, no codec dependencies, pygame decodes natively.
- **Dead-man's switch**: Server stops all motors if no control message for 500ms. Non-negotiable safety feature.
- **mDNS for discovery**: Pi broadcasts as `robothector.local`. UDP beacon as fallback.
- **Two-port server**: HTTP 5000 (video) + WebSocket 8765 (control). Simple, debuggable.

## Project Roadmap

### Phase 0: SSH & Network Discovery [Current Phase]
Get connected to the Pi inside the robot. No screen/keyboard access.
- Research Steam Deck networking (SteamOS/mDNS constraints)
- Configure Avahi on Pi (`robothector.local`)
- Set up passwordless SSH
- UDP beacon fallback + connection test script

### Phase 1: Hardware Diagnostics
Verify everything works over SSH before writing server code.
- Confirm GPIO pinout (resolve the 3-way conflict)
- Test camera module (libcamera + Picamera2)
- Build unified hardware test script

### Phase 2: Foundation & Project Structure
Restructure the codebase for client/server.
- Create `server/` and `client/` directories
- Define WebSocket JSON protocol (`docs/protocol.md`)
- Extract `server/motors.py` from `joystick.py` (BCM pins, arcade mixing)
- Extract `server/sirens.py` from `joystick.py`
- Create `requirements-server.txt` and `requirements-client.txt`

### Phase 3: Client/Server + Video Streaming
The main build — drive the robot from a Steam Deck.
- WebSocket control server with dead-man's switch
- MJPEG camera server (refactored from `webapp/app.py`)
- Unified server entry point (`python3 -m server.main`)
- Steam Deck pygame client: joystick input, video display, HUD
- systemd service for auto-start on Pi
- End-to-end integration test

### Phase 4: Bidirectional Audio
Talk through the robot.
- Research audio stacks (PipeWire on Deck, ALSA on Pi)
- Pi mic → Steam Deck speaker (environment audio, UDP 5001)
- Steam Deck mic → Pi speaker (operator voice, UDP 5002)
- Push-to-talk UI controls

## Task Tracking

Using [Beads](https://beads.dev) (`bd` CLI). 33 items tracked: 5 epics + 28 tasks with full dependency graph.

```
bd ready          # See what's unblocked
bd list --pretty  # Tree view of all tasks
bd show <id>      # Task details
bd update <id> --status in_progress  # Claim work
bd close <id>     # Mark done
```

## Repository

- Remote: `git@github.com:sankao/robothector.git`
- Branch: `master`
- No CI/CD, no test suite, no linter configured
