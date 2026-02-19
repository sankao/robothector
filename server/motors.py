"""Motor control module for L298N H-bridge.

Tank drive via GPIO pins. Supports arcade mixing from joystick input.
Uses BCM pin numbering. Verified pinout from pinout.md:
  GPIO 26 = IN1 (brown)  \\ Motor A
  GPIO 19 = IN2 (black)  /
  GPIO 13 = IN3 (white)  \\ Motor B
  GPIO  6 = IN4 (grey)   /
"""

try:
    import RPi.GPIO as GPIO
    _has_gpio = True
except ImportError:
    _has_gpio = False

# BCM pin numbers — verified against physical wiring
IN1 = 26  # Motor A forward
IN2 = 19  # Motor A backward
IN3 = 13  # Motor B forward
IN4 = 6   # Motor B backward

_initialized = False


def init():
    global _initialized
    if _has_gpio:
        GPIO.setmode(GPIO.BCM)
        GPIO.setwarnings(False)
        for pin in (IN1, IN2, IN3, IN4):
            GPIO.setup(pin, GPIO.OUT)
            GPIO.output(pin, GPIO.LOW)
    _initialized = True
    _log("motors initialized" + (" (GPIO)" if _has_gpio else " (stub)"))


def cleanup():
    global _initialized
    stop()
    if _has_gpio:
        GPIO.cleanup()
    _initialized = False
    _log("motors cleaned up")


def arcade_mix(axis_x: float, axis_y: float) -> tuple[float, float]:
    """Convert arcade joystick input to left/right motor speeds.

    Args:
        axis_x: -1.0 (left) to 1.0 (right) — steering
        axis_y: -1.0 (forward) to 1.0 (backward) — throttle

    Returns:
        (left, right) each in range -1.0 to 1.0
    """
    throttle = -axis_y  # forward is negative on joystick, positive for motors
    turn = axis_x
    left = max(-1.0, min(1.0, throttle + turn))
    right = max(-1.0, min(1.0, throttle - turn))
    return left, right


def set_motors(left: float, right: float):
    """Set motor speeds. Each value from -1.0 (full backward) to 1.0 (full forward).

    Currently digital only (on/off per direction). PWM speed control can be
    added later using the L298N ENA/ENB pins.
    """
    _set_motor_a(left)
    _set_motor_b(right)


def stop():
    """Stop both motors immediately."""
    if _has_gpio:
        for pin in (IN1, IN2, IN3, IN4):
            GPIO.output(pin, GPIO.LOW)
    _log("motors stopped")


def _set_motor_a(speed: float):
    if not _has_gpio:
        return
    if speed > 0.1:
        GPIO.output(IN1, GPIO.HIGH)
        GPIO.output(IN2, GPIO.LOW)
    elif speed < -0.1:
        GPIO.output(IN1, GPIO.LOW)
        GPIO.output(IN2, GPIO.HIGH)
    else:
        GPIO.output(IN1, GPIO.LOW)
        GPIO.output(IN2, GPIO.LOW)


def _set_motor_b(speed: float):
    if not _has_gpio:
        return
    if speed > 0.1:
        GPIO.output(IN3, GPIO.HIGH)
        GPIO.output(IN4, GPIO.LOW)
    elif speed < -0.1:
        GPIO.output(IN3, GPIO.LOW)
        GPIO.output(IN4, GPIO.HIGH)
    else:
        GPIO.output(IN3, GPIO.LOW)
        GPIO.output(IN4, GPIO.LOW)


def _log(msg: str):
    print(f"[motors] {msg}")
