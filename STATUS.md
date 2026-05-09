# Robothector - Project Status

> Last refreshed: **2026-05-09**. Phases 0-3 complete. Phase 4 (audio) in progress.

## What Is It

Robothector is a Raspberry Pi-powered robot vehicle with emergency-response themes (firefighter/ambulance) for Hector. It's remotely operated over WiFi from any pygame-compatible client (laptop, Steam Deck, anything with a USB gamepad) with live MJPEG video and (in progress) bidirectional I2S audio so the operator can hear and talk through the robot.

## Phase progress

| Phase | What it covered | Status |
|---|---|---|
| 0 | SSH, mDNS, UDP beacon discovery | ✅ done |
| 1 | Hardware diagnostics (GPIO, camera) | ✅ done |
| 2 | Refactor to `client/` + `server/` + WS+JSON protocol | ✅ done |
| 3 | Remote drive + MJPEG video + dead-man's switch + systemd unit | ✅ done |
| **4** | **Bidirectional I2S audio (mic + amp + speaker)** | **🟠 in progress** |

## Current Hardware

| Component | Details |
|---|---|
| Brain | Raspberry Pi in chassis |
| Motors | 2× DC motors via L298N H-bridge, tank drive (no servo, no PWM yet) |
| Camera | Pi Camera Module (CSI ribbon) |
| Sirens | 3× WAV files (firefighter, ambulance, reverse) — local pygame.mixer playback |
| Mode buttons | 2× GPIO buttons (firefighter / ambulance) |
| Display | 800×480 (carried over, unused in current arch) |
| Power | Plan: USB-C PD power bank + CH224K trigger @ 9V → L298N + USB-A 5V → Pi (decided 2026-05-09) |
| Audio modules | INMP441 I2S mic + MAX98357A I2S amp + 4-8Ω speaker — **in hand, not wired** |

### GPIO map (current)

| Wire colour | GPIO (BCM) | Board pin | Function |
|---|---|---|---|
| brown | 26 | 37 | L298N IN1 |
| black | 19 | 35 | L298N IN2 |
| white | 13 | 33 | L298N IN3 |
| gray  | 6  | 31 | L298N IN4 |
| — | GND | 39 | common ground |

Full reference + planned audio pins + recommended Dupont colours: `docs/diagrams/pi-pinout.{pdf,svg,tex}` and `docs/diagrams/wiring.{pdf,svg,tex}`.

## Software state

Modular client/server architecture, both ends running pygame + asyncio + websockets:

### Server (Pi)

| Module | Lines | Role |
|---|---|---|
| `server/main.py` | 89 | Unified entry point, wires up all subsystems |
| `server/control.py` | 143 | WebSocket server (port 8765), single-client lock, 500 ms dead-man's switch, 5 Hz state broadcast |
| `server/motors.py` | 111 | L298N tank drive, arcade-mix from joystick axes |
| `server/sirens.py` | 68 | pygame.mixer playback for the 3 emergency-vehicle WAVs |
| `server/camera.py` | 153 | MJPEG streamer @ port 5000 (picamera2 + placeholder fallback) |
| `server/discovery.py` | 87 | UDP beacon @ port 5555 advertising the Pi as `robothector` |
| `server/hardware_test.py` | 115 | Diagnostic script — GPIO + camera bringup |
| `server/motor_test.py` | 73 | H-bridge sanity loop |
| `scripts/install-service.sh` | — | Installs `robothector.service` systemd unit |

### Client (any pygame host)

| Module | Lines | Role |
|---|---|---|
| `client/main.py` | 100 | pygame main loop, ties joystick → network → video → UI |
| `client/network.py` | 147 | WebSocket client, reconnect, heartbeat |
| `client/joystick.py` | 89 | pygame joystick polling, axis normalisation |
| `client/video.py` | 98 | MJPEG fetch + pygame.image decode |
| `client/ui.py` | 102 | HUD overlay (mode, RTT, connection state) |
| `client/discovery.py` | 52 | UDP beacon listener (auto-find robot on the LAN) |
| `client/test_connection.py` | 127 | One-shot smoke test |

### Protocol (`docs/protocol.md`)

WebSocket JSON messages:

- Client → server: `drive` (axis_x, axis_y, ~20 Hz), `mode` (firefighter/ambulance/empty), `ping`
- Server → client: `state` (~5 Hz), `pong`, `error`

No audio messages defined yet — Phase 4 will extend.

## What works today

- Drive the robot from this laptop (or any pygame host) via Steam Deck *or* a USB gamepad
- Live MJPEG video on the client window
- Emergency mode toggle plays local sirens on the robot
- Auto-discovery via mDNS and UDP beacon (no manual IP needed)
- Graceful no-Pi fallback so the server boots cleanly on dev machines for code work

## What's missing for Phase 4

Hardware-side, ordered:

1. Move IN2 wire from GPIO 19 (pin 35) → **GPIO 17 (pin 11)**. GPIO 16 is *not* an option (claimed by the I2S overlay for the amp's SD_MODE pin). One-line update to `server/motors.py` accompanies this rewire.
2. Wire the INMP441 mic (3.3V / GND / I2S BCLK+LRCLK+SD) and the MAX98357A amp (5V / GND / I2S BCLK+LRCLK+DIN + speaker) per `docs/diagrams/wiring.{pdf,svg}`.
3. Edit `/boot/firmware/config.txt`: enable `dtparam=i2s=on` and `dtoverlay=googlevoicehat-soundcard` (or the custom duplex overlay per `docs/audio-design.md`). Reboot.
4. Validate with shell: `arecord -D plughw:0 -c1 -r16000 -fS16_LE -d3 test.wav` then `aplay test.wav`. Must work before any Python.

Code-side, ~600 lines total, ordered:

5. `docs/protocol.md` extension: new `audio_listen` and `audio_talk` WS messages
6. `server/audio.py` (~280 lines): single module with capture thread (mic → UDP :5556) and playback thread (UDP :5557 → amp), enabled/disabled via control.py
7. `client/audio.py` (~280 lines): mirror — capture thread (Deck mic → UDP :5557) and playback thread (UDP :5556 → speakers)
8. `client/main.py` + `client/ui.py`: PTT button on L1 (push-to-talk), listen toggle on R1, HUD icons
9. `requirements-server.txt` + `requirements-client.txt`: add `sounddevice`, `numpy`
10. End-to-end test: drive + video + listen + push-to-talk simultaneously, latency tuning if needed (target ≤ 300 ms)

The code half can be developed entirely on this laptop with `uv add sounddevice numpy` and a UDP loopback test — no hardware required to write or unit-test it. Hardware is only needed for final ALSA validation and live latency tuning.

## Active Beads issues

26 closed, 11 open. Use `bd list --pretty` after running `bd migrate --update-repo-id` (legacy DB on fresh clone). Open items map 1:1 to the Phase 4 hardware + code list above.

## Open decisions / pending

- **Power**: PD bank + 9V trigger module, decided 2026-05-09. PD trigger module (CH224K-based, ~$3) needs ordering.
- **Motor voltage**: confirm motors are 6V TT-class (stay with PD 9V profile) vs 12V (switch to PD 12V profile). Motor sticker not yet read.
- **PWM speed control**: deferred. ENA/ENB jumpers still in place. Future upgrade requires moving IN3 off GPIO 13 to free the PWM channel; not blocking Phase 4.

## Repository

- Remote: `git@github.com:sankao/robothector.git`
- Branch: `master`
- No CI, no test suite, no linter — would be a Phase 5 nice-to-have

## Reference docs

- `docs/protocol.md` — WebSocket message schema
- `docs/audio-design.md` — I2S overlay choice, ALSA config, jitter buffer sizing, GPIO 19 rewire reasoning
- `docs/steamdeck-env.md` — networking notes specific to SteamOS (mDNS quirks etc.)
- `docs/diagrams/wiring.{pdf,svg,tex}` — system-level block diagram
- `docs/diagrams/pi-pinout.{pdf,svg,tex}` — full 40-pin GPIO header + wire-colour reference
- `pinout.md` — text wiring tables
- `CLAUDE.md` / `AGENTS.md` — agent-specific build notes
