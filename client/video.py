"""MJPEG stream receiver and pygame surface decoder.

Connects to the server's MJPEG HTTP endpoint in a background thread
and decodes JPEG frames into pygame Surfaces.
"""

import io
import threading
import time
import urllib.request

import pygame


class VideoStream:
    def __init__(self, host: str = "robothector.local", video_port: int = 5000):
        self._host = host
        self._video_port = video_port
        self._thread = None
        self._running = False
        self._connected = False
        self._frame = None
        self._lock = threading.Lock()

    def start(self):
        """Start the background stream reader thread."""
        self._running = True
        self._thread = threading.Thread(target=self._run_loop, daemon=True)
        self._thread.start()

    def stop(self):
        """Stop the background thread."""
        self._running = False
        if self._thread is not None:
            self._thread.join(timeout=5.0)

    def get_frame(self) -> pygame.Surface | None:
        """Get the latest decoded frame, or None if unavailable."""
        with self._lock:
            return self._frame

    def is_connected(self) -> bool:
        return self._connected

    def _run_loop(self):
        """Connect to MJPEG stream and decode frames."""
        while self._running:
            url = f"http://{self._host}:{self._video_port}/video_feed"
            try:
                _log(f"connecting to {url}...")
                stream = urllib.request.urlopen(url, timeout=5)
                self._connected = True
                _log("connected")
                self._read_stream(stream)
            except Exception as e:
                _log(f"stream error: {e}")
                self._connected = False
            finally:
                self._connected = False

            if self._running:
                time.sleep(2.0)

    def _read_stream(self, stream):
        """Parse multipart MJPEG stream and decode frames."""
        buf = b""
        while self._running:
            chunk = stream.read(4096)
            if not chunk:
                break
            buf += chunk

            # Find JPEG start (FFD8) and end (FFD9) markers
            while True:
                start = buf.find(b"\xff\xd8")
                end = buf.find(b"\xff\xd9", start + 2) if start != -1 else -1
                if start == -1 or end == -1:
                    # Keep only from last potential start marker
                    if start != -1:
                        buf = buf[start:]
                    elif len(buf) > 65536:
                        buf = buf[-4096:]
                    break

                jpeg_data = buf[start:end + 2]
                buf = buf[end + 2:]

                try:
                    bio = io.BytesIO(jpeg_data)
                    surface = pygame.image.load(bio, "frame.jpg")
                    with self._lock:
                        self._frame = surface
                except Exception:
                    pass


def _log(msg: str):
    print(f"[video] {msg}")
