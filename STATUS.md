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
| 4a | Protocol module (typed messages) + 40 tests | ✅ done |
| 4b | Audio packet wire format + jitter buffer + 35 tests | ✅ done |
| 4c | Audio I/O abstraction (fakes + lazy sounddevice) + 13 tests | ✅ done |
| 4d | `server/audio.py` + UDP loopback tests + 9 tests | ✅ done |
| 4e | `client/audio.py` + engine refactor + 7 tests | ✅ done |
| 4f | End-to-end loopback (server + client in one process) + 6 tests | ✅ done |
| **4g** | **Wire PTT/listen buttons in `client/main.py` + UI icons** | **next** |
| 4z | Hardware bringup (IN2 rewire, mic+amp wiring, I2S overlay) | ⏳ in parallel |
| 5 | Final demo: drive + video + listen + talk over WiFi | ⏳ blocked on 4g + 4z |

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

## Phase 4 — detailed breakdown

The implementation is split into independently-shippable sub-phases. Sub-phases 4a-4e are pure code and can be developed on any laptop with `uv add pytest sounddevice numpy`. Sub-phase 4z is the hardware bringup, parallelisable with 4a-4e.

### 4a — Protocol module + tests (no hardware, no audio)

Foundation. Replaces ad-hoc JSON parsing in `server/control.py` with a typed message layer that both ends share, and lays down the testing infrastructure for everything that follows.

- `protocol/__init__.py`, `protocol/messages.py` — frozen dataclasses for every WS message (existing: `drive`, `mode`, `ping`, `state`, `pong`, `error`; new: `audio_listen`, `audio_talk`)
- `protocol/messages.py` — `parse_client_message(raw_json: str) -> ClientMessage` with input validation; `serialize(msg) -> str` for outgoing
- `tests/test_protocol_messages.py` — round-trip tests, range validation (axis_x/y in [-1, 1]), unknown-type rejection, version compatibility (extra fields ignored)
- `pyproject.toml` — add `[tool.pytest.ini_options]`, optional `dev` group with `pytest`
- `docs/protocol.md` — extend with `audio_listen` / `audio_talk` message specs and the new `state` fields
- `server/control.py` — refactored to dispatch via `protocol.messages` (motors/sirens dispatch unchanged externally)
- `tests/test_server_control.py` — feed scripted message sequences into a `ControlServer`, assert motor/siren state, validates dead-man's switch with a fake clock

### 4b — Audio packet format + jitter buffer (no hardware)

Pure-data layer. Defines the wire format for PCM-over-UDP and the reorder buffer that absorbs network jitter. Fully unit-testable with synthetic packets.

- `protocol/audio_packet.py` — `AudioPacket` dataclass with `to_bytes()` / `from_bytes()`, 12-byte header (magic, seq, timestamp_ms, sample_count) + S16_LE mono payload
- `protocol/jitter_buffer.py` — `JitterBuffer` class: push out-of-order packets, pop in-sequence with silence fill on loss, target depth configurable (default 80 ms = 2 packets)
- `tests/test_audio_packet.py` — round-trip, malformed input, magic-byte rejection, payload-size validation
- `tests/test_jitter_buffer.py` — in-order delivery, late-but-recoverable, irrecoverable loss → silence chunk, duplicate suppression, max-depth eviction

### 4c — Audio I/O abstraction (no hardware needed for tests)

Wraps `sounddevice` behind an interface so tests can swap in fakes and so the same code runs on Pi, laptop, and CI without `[Errno -9996] Invalid input device`.

- `protocol/audio_io.py` — `AudioSource` and `AudioSink` ABCs with `read(n_samples) -> bytes` / `write(bytes)` plus `start()` / `stop()`
- `protocol/audio_io.py` — `SoundDeviceSource`, `SoundDeviceSink` real implementations (lazy import of `sounddevice` so non-audio code still imports cleanly)
- `protocol/audio_io.py` — `FakeAudioSource` (replays a fixed list of byte chunks), `FakeAudioSink` (appends writes to a list)
- `tests/test_audio_io_fakes.py` — fakes do what they say
- The real implementations are smoke-tested manually; no CI-runnable test for them since they need a sound device

### 4d — Server audio module + integration (no hardware)

Wires the packet layer + I/O abstraction into the server's asyncio loop, hung off the WebSocket control plane.

- `server/audio.py` — `AudioServer` class with `capture_loop` (`AudioSource` → UDP send to client on port 5556) and `playback_loop` (UDP recv on port 5557 → `JitterBuffer` → `AudioSink`), both async
- `server/audio.py` — controlled by `enable_listen(client_addr)` / `disable_listen()` / `enable_talk()` / `disable_talk()` called from `server/control.py`
- `server/control.py` — handle `audio_listen` and `audio_talk` messages; expose audio state in `state` broadcast
- `server/main.py` — instantiate `AudioServer` alongside camera/control/sirens with `FakeAudioSource`/`FakeAudioSink` if `sounddevice` import or device open fails
- `tests/test_server_audio.py` — drive a real `AudioServer` with `FakeAudioSource` + a fake UDP socket pair, assert the right packets land at the configured client address; verify enable/disable cleanly start/stop the threads

### 4e — Client audio module + UI integration (no hardware)

Mirror of the server. Plus push-to-talk wiring on the gamepad.

- `client/audio.py` — `AudioClient` class with capture (mic → UDP server:5557) and playback (UDP :5556 → speakers via `JitterBuffer`)
- `client/main.py` — bind L1 to push-to-talk: on press, send `audio_talk(enabled=True)` and start capture; on release, stop and send `audio_talk(enabled=False)`. Bind R1 to listen toggle.
- `client/ui.py` — HUD: 🎤 indicator while transmitting, 🔊 while receiving, mute icon idle
- `tests/test_client_audio.py` — drive `AudioClient` with `FakeAudioSource` + fake UDP, assert packets, assert PTT state transitions

### 4f — End-to-end loopback (no hardware)

Final integration test before deploying to Pi. Both client and server run on the same laptop, talking to themselves via localhost UDP. Measures round-trip latency.

- `tests/test_loopback_e2e.py` — spawn `AudioServer` + `AudioClient` in the same process, both with `FakeAudioSource` feeding a known sine wave, assert the wave survives the round trip with bounded latency and acceptable packet loss
- Manual test on the actual laptop with real mic + speakers confirms live audio loop works

### 4z — Hardware bringup (parallel with code, blocks final demo)

1. Move IN2 wire from GPIO 19 (pin 35) → **GPIO 17 (pin 11)**. GPIO 16 is *not* an option (claimed by the I2S overlay for the amp's SD_MODE pin). One-line update to `server/motors.py` accompanies this rewire.
2. Wire the INMP441 mic (3.3V / GND / I2S BCLK+LRCLK+SD) and the MAX98357A amp (5V / GND / I2S BCLK+LRCLK+DIN + speaker) per `docs/diagrams/wiring.{pdf,svg}`.
3. Edit `/boot/firmware/config.txt`: enable `dtparam=i2s=on` and `dtoverlay=googlevoicehat-soundcard` (or the custom duplex overlay per `docs/audio-design.md`). Reboot.
4. Validate with shell: `arecord -D plughw:0 -c1 -r16000 -fS16_LE -d3 test.wav` then `aplay test.wav`. Must work before swapping `FakeAudioSource` → `SoundDeviceSource` in `server/main.py`.
5. Final demo: drive + video + listen + push-to-talk simultaneously over WiFi, latency target ≤ 300 ms.

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
