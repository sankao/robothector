"""Gamepad input handler.

Reads left stick axes and shoulder buttons from any SDL-compatible gamepad.
Axis mapping follows standard SDL layout. Mode buttons are toggles.
"""

import pygame

DEADZONE = 0.1

# Standard SDL gamepad button indices
BUTTON_L1 = 4  # toggle firefighter
BUTTON_R1 = 5  # toggle ambulance

_joystick = None
_current_mode = ""


def init():
    """Initialize pygame joystick subsystem and open first gamepad if present."""
    pygame.joystick.init()
    _open_first_joystick()


def _open_first_joystick():
    """Try to open the first available joystick."""
    global _joystick
    if _joystick is not None:
        return
    count = pygame.joystick.get_count()
    if count == 0:
        _log("no joystick found — using neutral values")
        return
    _joystick = pygame.joystick.Joystick(0)
    _joystick.init()
    _log(f"opened: {_joystick.get_name()} ({_joystick.get_numaxes()} axes, {_joystick.get_numbuttons()} buttons)")


def cleanup():
    """Shut down joystick subsystem."""
    global _joystick
    if _joystick is not None:
        _joystick.quit()
        _joystick = None
    pygame.joystick.quit()


def handle_event(event: pygame.event.Event):
    """Process joystick-related events (buttons, hotplug)."""
    global _joystick, _current_mode

    if event.type == pygame.JOYDEVICEADDED:
        _log(f"controller connected (device {event.device_index})")
        _open_first_joystick()

    elif event.type == pygame.JOYDEVICEREMOVED:
        _log("controller disconnected")
        _joystick = None

    elif event.type == pygame.JOYBUTTONDOWN:
        if event.button == BUTTON_L1:
            _current_mode = "" if _current_mode == "firefighter" else "firefighter"
        elif event.button == BUTTON_R1:
            _current_mode = "" if _current_mode == "ambulance" else "ambulance"


def get_input() -> dict:
    """Read current joystick state.

    Returns:
        dict with axis_x, axis_y, mode
    """
    if _joystick is None:
        return {"axis_x": 0.0, "axis_y": 0.0, "mode": _current_mode}

    axis_x = _joystick.get_axis(0)
    axis_y = _joystick.get_axis(1)

    # Apply deadzone
    if abs(axis_x) < DEADZONE:
        axis_x = 0.0
    if abs(axis_y) < DEADZONE:
        axis_y = 0.0

    return {"axis_x": axis_x, "axis_y": axis_y, "mode": _current_mode}


def _log(msg: str):
    print(f"[joystick] {msg}")
