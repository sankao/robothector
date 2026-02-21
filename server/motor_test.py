"""Motor test cycle — run on Pi to verify GPIO and H-bridge wiring.

Usage:
    ssh robothector 'cd ~/robothector && python3 -m server.motor_test'
    ssh robothector 'cd ~/robothector && python3 -m server.motor_test --duration 5'
"""

import argparse
import time
import sys

try:
    import RPi.GPIO as GPIO
except ImportError:
    print("ERROR: RPi.GPIO not available. Run this on the Pi.")
    sys.exit(1)

PINS = {26: "IN1", 19: "IN2", 13: "IN3", 6: "IN4"}

STEPS = [
    ("Motor A FORWARD",  "IN1=HIGH IN2=LOW  → left motor should spin forward",  [26]),
    ("Motor A BACKWARD", "IN1=LOW  IN2=HIGH → left motor should spin backward", [19]),
    ("Motor B FORWARD",  "IN3=HIGH IN4=LOW  → right motor should spin forward", [13]),
    ("Motor B BACKWARD", "IN3=LOW  IN4=HIGH → right motor should spin backward", [6]),
]


def main():
    parser = argparse.ArgumentParser(description="Motor GPIO test cycle")
    parser.add_argument("-d", "--duration", type=int, default=3, help="Seconds per step (default: 3)")
    args = parser.parse_args()

    GPIO.setmode(GPIO.BCM)
    GPIO.setwarnings(False)
    for pin in PINS:
        GPIO.setup(pin, GPIO.OUT)
        GPIO.output(pin, GPIO.LOW)

    total = len(STEPS) * (args.duration + 1)
    print(f"{'=' * 50}")
    print(f"  MOTOR TEST CYCLE")
    print(f"  {args.duration}s per step, {total}s total")
    print(f"  Pins: {', '.join(f'GPIO {p} = {n}' for p, n in PINS.items())}")
    print(f"{'=' * 50}")
    print()

    for i, (name, expect, high_pins) in enumerate(STEPS, 1):
        print(f"  [{i}/{len(STEPS)}] {name}")
        print(f"         {expect}")
        print(f"         ", end="", flush=True)

        for p in high_pins:
            GPIO.output(p, GPIO.HIGH)

        for remaining in range(args.duration, 0, -1):
            print(f"{remaining}...", end=" ", flush=True)
            time.sleep(1)

        for p in high_pins:
            GPIO.output(p, GPIO.LOW)

        print("OFF")
        print()
        time.sleep(1)

    GPIO.cleanup()
    print(f"{'=' * 50}")
    print("  DONE — all pins back to LOW")
    print(f"{'=' * 50}")


if __name__ == "__main__":
    main()
