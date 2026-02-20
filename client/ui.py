"""HUD overlay rendering for the client display.

Renders camera feed, connection status, mode indicator, and joystick position.
"""

import pygame

SCREEN_W, SCREEN_H = 1280, 800
VIDEO_W, VIDEO_H = 640, 480

_font = None
_font_large = None


def init():
    """Initialize fonts."""
    global _font, _font_large
    _font = pygame.font.SysFont(None, 24)
    _font_large = pygame.font.SysFont(None, 48)


def render(screen: pygame.Surface, frame: pygame.Surface | None,
           state: dict | None, input_data: dict, connected: bool,
           video_connected: bool):
    """Render full UI frame."""
    screen.fill((20, 20, 20))

    # Camera feed
    if frame is not None:
        _draw_video(screen, frame)
    else:
        _draw_no_signal(screen)

    # Connection status (top-left)
    _draw_connection(screen, connected, video_connected)

    # Mode indicator (top-right)
    mode = input_data.get("mode", "")
    if mode:
        _draw_mode(screen, mode)

    # Joystick indicator (bottom-center)
    _draw_joystick_indicator(screen, input_data.get("axis_x", 0), input_data.get("axis_y", 0))


def _draw_video(screen: pygame.Surface, frame: pygame.Surface):
    """Scale and center the camera feed."""
    fw, fh = frame.get_size()
    scale = min(SCREEN_W / fw, SCREEN_H / fh)
    new_w, new_h = int(fw * scale), int(fh * scale)
    scaled = pygame.transform.scale(frame, (new_w, new_h))
    x = (SCREEN_W - new_w) // 2
    y = (SCREEN_H - new_h) // 2
    screen.blit(scaled, (x, y))


def _draw_no_signal(screen: pygame.Surface):
    """Show 'No Signal' placeholder."""
    text = _font_large.render("No Signal", True, (120, 120, 120))
    rect = text.get_rect(center=(SCREEN_W // 2, SCREEN_H // 2))
    screen.blit(text, rect)


def _draw_connection(screen: pygame.Surface, ws_connected: bool, video_connected: bool):
    """Draw connection status dots."""
    # WebSocket
    color = (0, 200, 0) if ws_connected else (200, 0, 0)
    pygame.draw.circle(screen, color, (20, 20), 8)
    label = _font.render("WS", True, (200, 200, 200))
    screen.blit(label, (34, 12))

    # Video
    color = (0, 200, 0) if video_connected else (200, 0, 0)
    pygame.draw.circle(screen, color, (20, 44), 8)
    label = _font.render("Video", True, (200, 200, 200))
    screen.blit(label, (34, 36))


def _draw_mode(screen: pygame.Surface, mode: str):
    """Draw mode label in top-right."""
    colors = {
        "firefighter": (255, 60, 60),
        "ambulance": (60, 120, 255),
    }
    color = colors.get(mode, (200, 200, 200))
    text = _font_large.render(mode.upper(), True, color)
    rect = text.get_rect(topright=(SCREEN_W - 20, 10))
    screen.blit(text, rect)


def _draw_joystick_indicator(screen: pygame.Surface, axis_x: float, axis_y: float):
    """Draw a small joystick position indicator at bottom-center."""
    cx, cy = SCREEN_W // 2, SCREEN_H - 60
    radius = 40

    # Outer ring
    pygame.draw.circle(screen, (80, 80, 80), (cx, cy), radius, 2)

    # Stick position
    sx = cx + int(axis_x * (radius - 6))
    sy = cy + int(axis_y * (radius - 6))
    pygame.draw.circle(screen, (0, 180, 255), (sx, sy), 6)
