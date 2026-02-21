# Audio Design — Bidirectional I2S Audio

## Overview

Two-way voice between client (desktop/Steam Deck) and robot (Pi 4) over LAN.

- **Pi → Client**: I2S MEMS mic captures robot environment, streams to client speakers
- **Client → Pi**: Client mic captures operator voice, streams to Pi I2S amplifier
- **Transport**: Raw PCM over UDP (16-bit mono 16kHz = 32 KB/s per direction)
- **Mode**: Push-to-talk first, full duplex later

## Hardware

| Module | I2S Pin | GPIO (BCM) | Board Pin | Notes |
|--------|---------|------------|-----------|-------|
| Shared | BCLK | 18 | 12 | Bit clock (both devices) |
| Shared | LRCLK | 19 | 35 | Frame sync (both devices) |
| INMP441 mic | DIN | 20 | 38 | Mic data into Pi |
| MAX98357A amp | DOUT | 21 | 40 | Speaker data out from Pi |

**GPIO 19 conflict**: Currently used by motor IN2. Must rewire IN2 to **GPIO 17 (pin 11)** before enabling I2S. See [GPIO Conflict Resolution](#gpio-19-conflict-resolution) below.

## I2S Kernel Configuration

### /boot/firmware/config.txt

```ini
# Disable onboard audio
#dtparam=audio=on

# Enable I2S bus
dtparam=i2s=on

# Full-duplex I2S sound card (supports both capture and playback)
dtoverlay=googlevoicehat-soundcard

# Required for dmix/dsnoop ALSA plugins
dtoverlay=i2s-mmap
```

**Do NOT** also add `dtoverlay=max98357a` — that conflicts. The `googlevoicehat-soundcard` overlay provides both directions.

### Fallback: Custom duplex overlay

If `googlevoicehat-soundcard` has issues on Bookworm, compile a custom `simple-audio-card` overlay with two DAI links (one `spdif-dit` for playback, one `spdif-dir` for capture). See `scripts/i2s-duplex-overlay.dts` if needed.

## ALSA Configuration

### /etc/asound.conf

```conf
pcm.i2scard {
    type hw
    card 0
    device 0
}

pcm.dmixer {
    type dmix
    ipc_key 1024
    slave {
        pcm "i2scard"
        rate 48000
        channels 2
        period_size 1024
        buffer_size 8192
    }
}

pcm.dsnooper {
    type dsnoop
    ipc_key 1025
    slave {
        pcm "i2scard"
        rate 48000
        channels 2
        period_size 1024
        buffer_size 8192
    }
}

pcm.!default {
    type asym
    playback.pcm "dmixer"
    capture.pcm "dsnooper"
}

ctl.!default {
    type hw
    card 0
}
```

### Verification

```bash
aplay -l              # Should show I2S card for playback
arecord -l            # Should show I2S card for capture
cat /proc/asound/pcm  # Both directions listed

# Test speaker
speaker-test -c 2 -D plughw:0,0 -t sine

# Test mic (5 second recording)
arecord -D plughw:0 -c1 -r 48000 -f S32_LE -t wav -d 5 test.wav
aplay -D plughw:0 test.wav
```

Note: INMP441 outputs 32-bit data (`S32_LE`) but only 24 bits are significant. Downsample in software for 16-bit streaming.

## Python Audio Library

### Decision: `sounddevice`

| | sounddevice | pyaudio |
|-|-------------|---------|
| Backend | PortAudio/ALSA | PortAudio/ALSA |
| Data format | NumPy arrays | Raw bytes |
| Maintained | Active (2024+) | Stale |
| I2S on Pi | Works via ALSA | Known issues |
| Steam Deck | Works via PipeWire-ALSA | Works |

Install:
```bash
# Pi
sudo apt-get install -y libportaudio2
uv pip install sounddevice numpy

# Desktop/Steam Deck
uv pip install sounddevice numpy
```

Fallback if sounddevice has I2S issues: `pyalsaaudio` (talks ALSA directly, no PortAudio layer).

## Transport Protocol

### Decision: Raw PCM over UDP

- **Format**: 16-bit signed LE, mono, 16kHz
- **Chunk size**: 640 samples = 40ms = 1280 bytes per packet
- **Bandwidth**: ~32 KB/s per direction (negligible vs video stream)
- **Ports**: UDP 5556 (Pi→Client), UDP 5557 (Client→Pi)

Raw PCM chosen over Opus because:
- 32 KB/s is negligible on LAN
- Zero codec complexity and CPU overhead on Pi
- Lower latency (no algorithmic delay)
- Simpler debugging (dump to WAV trivially)

Opus can be added later if needed for internet streaming or bandwidth-constrained links.

### Packet format

```
[seq:uint16][audio:1280 bytes of int16 PCM]
```

2-byte sequence number for loss detection. Total packet: 1282 bytes.

## Latency Budget

Target: <300ms one-way.

| Stage | Estimated Time |
|-------|---------------|
| I2S hardware capture | 1-2ms |
| ALSA period fill (640 samples @ 16kHz) | 40ms |
| sounddevice callback + UDP send | ~1ms |
| Network transit (WiFi LAN) | 1-5ms |
| Jitter buffer (1-2 packets) | 40-80ms |
| Playback buffer (1 period) | 40ms |
| **Total one-way** | **~80-125ms** |

Well within the 300ms target. Can be tuned further with smaller periods (320 samples = 20ms).

**Warning**: Stop `pigpiod` if running — it conflicts with the I2S PCM clock and causes audio at 50% speed.

## GPIO 19 Conflict Resolution

### Problem

GPIO 19 is used by both motor IN2 and I2S LRCLK.

### Solution: Move IN2 to GPIO 17 (pin 11)

Why GPIO 17:
- General purpose, no alternate function conflicts
- Not used by I2S (18/19/20/21), SPI (7-11), I2C (2-3), or UART (14-15)
- Not claimed by `googlevoicehat-soundcard` overlay (which claims GPIO 16 for SD_MODE)
- GPIO 16 was the first candidate but is taken by the overlay

Why not GPIO 12: Reserved for future PWM speed control (ENA pin).

### Changes required

1. **Physical**: Move black wire from pin 35 (GPIO 19) to pin 11 (GPIO 17)
2. **Software**: Update `IN2 = 19` → `IN2 = 17` in `server/motors.py`
3. **Docs**: Update `pinout.md` wiring table

## Architecture

```
┌──────────────────┐         UDP:5556         ┌──────────────────┐
│   Pi (Server)    │ ──── Pi mic audio ────▶  │  Client          │
│                  │                          │                  │
│  I2S INMP441 mic │                          │  sounddevice     │
│  sounddevice     │                          │  speaker output  │
│  capture @ 16kHz │         UDP:5557         │                  │
│                  │ ◀── client mic audio ──  │  sounddevice     │
│  MAX98357A amp   │                          │  mic capture     │
│  sounddevice     │                          │                  │
│  playback @16kHz │                          │                  │
└──────────────────┘                          └──────────────────┘
```

### Server modules (new)

- `server/audio.py` — I2S mic capture → UDP sender, UDP receiver → I2S amp playback
- Integrates with `server/main.py` alongside camera/motors/control

### Client modules (new)

- `client/audio.py` — mic capture → UDP sender, UDP receiver → speaker playback
- Push-to-talk toggle in `client/joystick.py` (button mapping TBD)
- Audio status in `client/ui.py` HUD

### WebSocket control messages

```json
{"type": "audio_start"}     // client requests audio streams start
{"type": "audio_stop"}      // client requests audio streams stop
{"type": "ptt", "active": true}   // push-to-talk state
```

## Implementation Order

1. Resolve GPIO 19 conflict (rewire + code change)
2. Configure I2S overlays and ALSA on Pi, verify with arecord/aplay
3. Implement Pi→Client audio (mic capture + UDP stream + client playback)
4. Implement Client→Pi audio (client mic + UDP stream + Pi playback)
5. Add push-to-talk UI controls
