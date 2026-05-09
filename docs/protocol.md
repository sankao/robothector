# Control Protocol

WebSocket JSON messages over **port 8765** carry the control plane.
MJPEG video over **HTTP port 5000**.
Audio PCM over UDP — server mic → client on **UDP 5556**, client mic → server on **UDP 5557**.

The canonical typed definitions for every WebSocket message live in
`protocol/messages.py`. This document is the human-readable spec; the
code is the source of truth.

## Client → Server

### Drive (sent at ~20 Hz)

```json
{"type": "drive", "axis_x": 0.0, "axis_y": 0.0}
```

- `axis_x`: -1.0 (full left) to 1.0 (full right) — steering. Out of range → ValueError.
- `axis_y`: -1.0 (full forward) to 1.0 (full backward) — throttle. Out of range → ValueError.

Server applies arcade-to-tank mixing:

```
left  = clamp(-axis_y + axis_x, -1, 1)
right = clamp(-axis_y - axis_x, -1, 1)
```

### Mode

```json
{"type": "mode", "mode": "firefighter"}
```

- `mode`: `""`, `"firefighter"`, or `"ambulance"`. Other values → ValueError.

### Ping

```json
{"type": "ping"}
```

### Audio listen (start/stop hearing the robot)

```json
{"type": "audio_listen", "enabled": true}
```

- `enabled`: when `true`, server starts capturing the INMP441 mic and streams S16_LE 16 kHz mono PCM to the client's UDP port **5556**. When `false`, capture stops and no UDP packets are emitted.
- Server reflects the state in subsequent `state` broadcasts.

### Audio talk (push-to-talk from client)

```json
{"type": "audio_talk", "enabled": true}
```

- `enabled`: when `true`, server begins listening on **UDP 5557** for incoming PCM packets and pumps them through to the MAX98357A amp. When `false`, server stops the playback thread.
- Client should send `enabled: true` *before* it starts pushing audio packets, and `enabled: false` *after* the user releases the PTT button.

## Server → Client

### State (sent at ~5 Hz)

```json
{
  "type": "state",
  "mode": "firefighter",
  "connected": true,
  "audio_listen": false,
  "audio_talk": false
}
```

- `audio_listen` / `audio_talk` mirror the most recent corresponding client request — used by the HUD to confirm the audio plane is in the requested state.

### Pong

```json
{"type": "pong"}
```

### Error

```json
{"type": "error", "message": "description"}
```

## Audio UDP wire format

Each audio packet is one UDP datagram. Header is 12 bytes big-endian, followed by a payload of `sample_count × 2` bytes (S16_LE mono PCM). See `protocol/audio_packet.py`.

```
 0     1     2     3     4     5     6     7     8     9    10    11
+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+
| 0xAB| 0xCD|    seq (uint32 BE)    | timestamp_ms (uint32 BE)| count |
+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+
|                payload (sample_count × int16 LE) ...
+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+
```

- `seq` — monotonic per stream; receiver uses it to reorder
- `timestamp_ms` — sender's monotonic clock, mod 2³² ms (~49 days)
- `sample_count` (uint16) — 640 = 40 ms @ 16 kHz (default; smaller for lower latency)
- `payload` — mono, little-endian signed 16-bit

Receivers maintain a `JitterBuffer` (see `protocol/jitter_buffer.py`) sized for ~80 ms of jitter (2 packets at default size). On packet loss, the buffer emits a silence chunk of the same length.

## Dead-Man's Switch

- No control message for 500 ms → server stops all motors
- No control message for 5 s → server enters safe mode, logs warning
- Client disconnect → immediate motor stop and audio threads idle
- Server startup → motors stopped, audio threads idle until first `audio_listen`/`audio_talk`

## Forward / backward compatibility

Parsers ignore unknown fields. Old clients can send messages to newer servers (audio fields default to disabled). Newer clients sending audio messages to an older server will get back `{"type": "error", "message": "unknown client message type: 'audio_listen'"}` — clients should treat that as "audio not supported, hide the audio UI".
