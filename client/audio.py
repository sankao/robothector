"""Client-side audio plane.

Mirror of `server.audio`. Composes one `AudioStreamSender`
(local mic -> server PTT port) and one `AudioStreamReceiver`
(server mic stream -> local speaker).

UI semantics (driven by gamepad buttons in `client/main.py`):
  start_listening()  — receive robot mic, play through laptop speaker
  start_talking()    — capture laptop mic, send to robot amp (PTT held)

The client knows the server's host because it just connected to it via
WebSocket; pass it to the constructor or update later via
`update_server_host()`.
"""

from __future__ import annotations

import socket

from protocol import DEFAULT_SAMPLES_PER_PACKET
from protocol.audio_engine import AudioStreamReceiver, AudioStreamSender
from protocol.audio_io import AudioSink, AudioSource

DEFAULT_CLIENT_LISTEN_PORT = 5556  # we recv robot mic here
DEFAULT_SERVER_LISTEN_PORT = 5557  # we send our mic here


class AudioClient:
    def __init__(
        self,
        source: AudioSource,
        sink: AudioSink,
        server_host: str,
        send_socket: socket.socket | None = None,
        recv_socket: socket.socket | None = None,
        client_listen_port: int = DEFAULT_CLIENT_LISTEN_PORT,
        server_listen_port: int = DEFAULT_SERVER_LISTEN_PORT,
        samples_per_packet: int = DEFAULT_SAMPLES_PER_PACKET,
    ) -> None:
        self.source = source
        self.sink = sink
        self.server_host = server_host
        self.client_listen_port = client_listen_port
        self.server_listen_port = server_listen_port
        self.samples_per_packet = samples_per_packet

        self._send_sock = send_socket or socket.socket(
            socket.AF_INET, socket.SOCK_DGRAM
        )
        if recv_socket is None:
            recv_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            recv_socket.bind(("0.0.0.0", client_listen_port))
        self._recv_sock = recv_socket

        # Sender pushes laptop mic up to the robot's recv port
        self._sender = AudioStreamSender(
            source=source,
            socket_=self._send_sock,
            dest_host=server_host,
            dest_port=server_listen_port,
            samples_per_packet=samples_per_packet,
            thread_name="audio-talk",
        )
        # Receiver listens for the robot's mic stream
        self._receiver = AudioStreamReceiver(
            sink=sink,
            socket_=self._recv_sock,
            samples_per_packet=samples_per_packet,
            thread_name="audio-listen",
        )

    def update_server_host(self, host: str) -> None:
        """Re-target after a reconnect."""
        self.server_host = host
        self._sender.update_dest(host, self.server_listen_port)

    # ---- listen direction (operator hears the robot) --------------------
    def start_listening(self) -> None:
        self._receiver.start()

    def stop_listening(self) -> None:
        self._receiver.stop()

    # ---- talk direction (push-to-talk) ----------------------------------
    def start_talking(self) -> None:
        self._sender.start()

    def stop_talking(self) -> None:
        self._sender.stop()

    def shutdown(self) -> None:
        self.stop_listening()
        self.stop_talking()
        for s in (self._send_sock, self._recv_sock):
            try:
                s.close()
            except OSError:
                pass

    # ---- introspection --------------------------------------------------
    @property
    def listening(self) -> bool:
        return self._receiver.is_running()

    @property
    def talking(self) -> bool:
        return self._sender.is_running()
