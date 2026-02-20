"""Hardware diagnostic script — run on Pi to verify motors and camera.

Usage: ssh robothector 'cd ~/robothector && uv run python -m server.hardware_test'
"""

import time
import sys


def test_motors() -> bool:
    """Test each motor: forward 1s, backward 1s, stop."""
    print("\n=== Motor Test ===")
    try:
        from server.motors import init, set_motors, stop, cleanup, _has_gpio
    except ImportError as e:
        print(f"FAIL: cannot import motors module: {e}")
        return False

    if not _has_gpio:
        print("SKIP: RPi.GPIO not available (not running on Pi?)")
        return False

    init()
    try:
        # Motor A
        print("Motor A forward...", end=" ", flush=True)
        set_motors(1.0, 0.0)
        time.sleep(1)
        print("backward...", end=" ", flush=True)
        set_motors(-1.0, 0.0)
        time.sleep(1)
        stop()
        print("OK")

        # Motor B
        print("Motor B forward...", end=" ", flush=True)
        set_motors(0.0, 1.0)
        time.sleep(1)
        print("backward...", end=" ", flush=True)
        set_motors(0.0, -1.0)
        time.sleep(1)
        stop()
        print("OK")

        # Both
        print("Both motors forward...", end=" ", flush=True)
        set_motors(1.0, 1.0)
        time.sleep(1)
        stop()
        print("OK")

        print("PASS: motors")
        return True
    except Exception as e:
        print(f"\nFAIL: motors — {e}")
        return False
    finally:
        cleanup()


def test_camera() -> bool:
    """Capture a single frame from picamera2 and verify it."""
    print("\n=== Camera Test ===")
    try:
        from picamera2 import Picamera2
    except ImportError as e:
        print(f"FAIL: cannot import picamera2: {e}")
        return False

    try:
        cam = Picamera2()
        config = cam.create_still_configuration()
        cam.configure(config)
        cam.start()
        time.sleep(1)  # warm-up
        frame = cam.capture_array()
        cam.stop()
        cam.close()

        if frame is not None and frame.size > 0:
            h, w = frame.shape[:2]
            print(f"Captured frame: {w}x{h}, size={frame.size} bytes")
            print("PASS: camera")
            return True
        else:
            print("FAIL: camera — empty frame")
            return False
    except Exception as e:
        print(f"FAIL: camera — {e}")
        return False


def main():
    print("Robothector Hardware Diagnostics")
    print("=" * 40)

    results = {
        "motors": test_motors(),
        "camera": test_camera(),
    }

    print("\n" + "=" * 40)
    print("Results:")
    all_pass = True
    for component, passed in results.items():
        status = "PASS" if passed else "FAIL"
        print(f"  {component}: {status}")
        if not passed:
            all_pass = False

    sys.exit(0 if all_pass else 1)


if __name__ == "__main__":
    main()
