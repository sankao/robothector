"""MJPEG camera streaming server.

Streams JPEG frames from Pi Camera Module 3 (IMX708) over HTTP.
Falls back to a placeholder on systems without a camera.
"""

import io
import threading
import time

try:
    from picamera2 import Picamera2
    from picamera2.encoders import JpegEncoder
    from picamera2.outputs import FileOutput
    _has_camera = True
except ImportError:
    _has_camera = False

from flask import Flask, Response, jsonify


class StreamingOutput(io.BufferedIOBase):
    """Thread-safe buffer for the latest JPEG frame."""

    def __init__(self):
        self.frame = None
        self.condition = threading.Condition()

    def write(self, buf):
        with self.condition:
            self.frame = buf
            self.condition.notify_all()
        return len(buf)


class CameraServer:
    def __init__(self):
        self._cam = None
        self._output = StreamingOutput()
        self._thread = None
        self._app = Flask(__name__)
        self._resolution = (640, 480)
        self._setup_routes()

    def _setup_routes(self):
        @self._app.route("/video_feed")
        def video_feed():
            return Response(
                self._generate_frames(),
                mimetype="multipart/x-mixed-replace; boundary=frame",
            )

        @self._app.route("/health")
        def health():
            return jsonify({
                "status": "ok",
                "resolution": list(self._resolution),
                "camera": _has_camera and self._cam is not None,
            })

    def _generate_frames(self):
        """Yield MJPEG frames as multipart response."""
        while True:
            with self._output.condition:
                self._output.condition.wait()
                frame = self._output.frame
            if frame is not None:
                yield (
                    b"--frame\r\n"
                    b"Content-Type: image/jpeg\r\n\r\n"
                    + frame
                    + b"\r\n"
                )

    def _start_camera(self):
        """Initialize and start the Pi camera."""
        if not _has_camera:
            _log("picamera2 not available, serving placeholder")
            self._start_placeholder()
            return

        try:
            self._cam = Picamera2()
            config = self._cam.create_video_configuration(
                main={"size": self._resolution}
            )
            self._cam.configure(config)
            encoder = JpegEncoder()
            self._cam.start_recording(encoder, FileOutput(self._output))
            _log(f"camera started at {self._resolution[0]}x{self._resolution[1]}")
        except Exception as e:
            _log(f"camera failed to start: {e}, using placeholder")
            self._cam = None
            self._start_placeholder()

    def _start_placeholder(self):
        """Write a placeholder frame periodically when no camera is available."""
        # Generate a placeholder JPEG using pygame (already a dependency)
        import pygame
        pygame.init()
        surface = pygame.Surface(self._resolution)
        surface.fill((30, 30, 30))
        font = pygame.font.SysFont(None, 36)
        text = font.render("NO CAMERA", True, (180, 180, 180))
        rect = text.get_rect(center=(self._resolution[0] // 2, self._resolution[1] // 2))
        surface.blit(text, rect)
        frame = pygame.image.tobytes(surface, "RGB")

        # Convert raw RGB to JPEG via PIL if available, otherwise use raw
        try:
            from PIL import Image
            img = Image.frombytes("RGB", self._resolution, frame)
            buf = io.BytesIO()
            img.save(buf, format="JPEG", quality=50)
            jpeg_frame = buf.getvalue()
        except ImportError:
            # Fallback: serve raw bytes (won't display as JPEG, but /health still works)
            _log("PIL not available, placeholder will not render")
            return

        def _loop():
            while True:
                self._output.write(jpeg_frame)
                time.sleep(0.5)

        t = threading.Thread(target=_loop, daemon=True)
        t.start()

    def start(self, port: int = 5000):
        """Start camera and HTTP server in a daemon thread."""
        self._start_camera()
        self._thread = threading.Thread(
            target=self._app.run,
            kwargs={"host": "0.0.0.0", "port": port, "threaded": True},
            daemon=True,
        )
        self._thread.start()
        _log(f"HTTP server started on port {port}")

    def stop(self):
        """Stop camera recording."""
        if self._cam is not None:
            try:
                self._cam.stop_recording()
                self._cam.close()
            except Exception as e:
                _log(f"camera stop error: {e}")
            self._cam = None
        _log("camera stopped")


def _log(msg: str):
    print(f"[camera] {msg}")
