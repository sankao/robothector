#!/usr/bin/python3
"""
Flask server for streaming video from the Raspberry Pi camera using Picamera2.
The HTML template can use an <img> tag referencing the '/video_feed' endpoint.
Run this script and then point your browser to http://<your-pi-ip>:5000
Note: Requires Picamera2 (and simplejpeg for JPEG encoding).
"""

import io
import logging
from threading import Condition

from flask import Flask, render_template, Response
from picamera2 import Picamera2
from picamera2.encoders import JpegEncoder
from picamera2.outputs import FileOutput

app = Flask(__name__)

# -------------------------------------------------------
# Updated Camera Code using Picamera2
# -------------------------------------------------------

class StreamingOutput(io.BufferedIOBase):
    def __init__(self):
        self.frame = None
        self.condition = Condition()
    
    def write(self, buf):
        # Each time a new frame is written from the encoder,
        # store it and notify all waiting threads.
        with self.condition:
            self.frame = buf
            self.condition.notify_all()
        return len(buf)

# Create a global StreamingOutput instance
output = StreamingOutput()

# Initialize Picamera2 and configure for 640x480 video streaming.
picam2 = Picamera2()
config = picam2.create_video_configuration(main={"size": (640, 480)})
picam2.configure(config)

# Start recording using the JpegEncoder and the FileOutput linked to our output.
picam2.start_recording(JpegEncoder(), FileOutput(output))


# -------------------------------------------------------
# Flask Endpoints (unchanged)
# -------------------------------------------------------

@app.route('/')
def index():
    # The index template should contain an <img src="/video_feed"> to display the stream.
    return render_template('index.html')


def generate_frames():
    """Video streaming generator function.
    Waits for a new frame to be available in output.frame and yields it as part of an MJPEG stream."""
    while True:
        with output.condition:
            output.condition.wait()
            frame = output.frame
        yield (b'--frame\r\n'
               b'Content-Type: image/jpeg\r\n\r\n' + frame + b'\r\n')


@app.route('/video_feed')
def video_feed():
    # Returns a multipart response generated by generate_frames.
    return Response(generate_frames(),
                    mimetype='multipart/x-mixed-replace; boundary=frame')


if __name__ == '__main__':
    try:
        # Run the Flask development server.
        app.run(host='0.0.0.0', debug=True, port=5000, use_reloader=False) finally:
        # Ensure the camera recording stops if the server is interrupted.
        picam2.stop_recording()
