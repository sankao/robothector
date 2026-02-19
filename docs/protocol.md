# Control Protocol

WebSocket JSON messages over port 8765. MJPEG video stream over HTTP port 5000.

## Client -> Server

### Drive (sent at ~20Hz)
```json
{"type": "drive", "axis_x": 0.0, "axis_y": 0.0}
```
- `axis_x`: -1.0 (full left) to 1.0 (full right) — steering
- `axis_y`: -1.0 (full forward) to 1.0 (full backward) — throttle

Server applies arcade-to-tank mixing:
```
left  = clamp(-axis_y + axis_x, -1, 1)
right = clamp(-axis_y - axis_x, -1, 1)
```

### Mode
```json
{"type": "mode", "mode": "firefighter"}
```
- `mode`: `"firefighter"`, `"ambulance"`, or `""`

### Ping
```json
{"type": "ping"}
```

## Server -> Client

### State (sent at ~5Hz)
```json
{"type": "state", "mode": "firefighter", "connected": true}
```

### Pong
```json
{"type": "pong"}
```

### Error
```json
{"type": "error", "message": "description"}
```

## Dead-Man's Switch

- No message for 500ms -> server stops all motors
- No message for 5s -> server logs warning, enters safe mode
- Client disconnect -> immediate motor stop
- Server startup -> motors always start stopped
