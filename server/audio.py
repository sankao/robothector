"""Server-side audio plane.

Composes one `AudioStreamSender` (mic -> client) and one
`AudioStreamReceiver` (client mic -> speaker) from
`protocol.audio_engine`. Both threads are toggled by the WebSocket
control plane via enable_listen / disable_listen / enable_talk /
disable_talk.
"""

from __future__ import annotations

import socket
from typing import Optional

from protocol import DEFAULT_SAMPLES_PER_PACKET
from protocol.audio_engine import AudioStreamReceiver, AudioStreamSender
from protocol.audio_io import AudioSink, AudioSource

DEFAULT_CLIENT_LISTEN_PORT = 5556  # we send mic packets here
DEFAULT_SERVER_LISTEN_PORT = 5557  # we recv talk packets here


class AudioServer:
    def __init__(
        self,
        source: AudioSource,
        sink: AudioSink,
        send_socket: socket.socket | None = None,
        recv_socket: socket.socket | None = None,
        client_listen_port: int = DEFAULT_CLIENT_LISTEN_PORT,
        server_listen_port: int = DEFAULT_SERVER_LISTEN_PORT,
        samples_per_packet: int = DEFAULT_SAMPLES_PER_PACKET,
    ) -> None:
        self.source = source
        self.sink = sink
        self.client_listen_port = client_listen_port
        self.server_listen_port = server_listen_port
        self.samples_per_packet = samples_per_packet

        self._send_sock = send_socket or socket.socket(
            socket.AF_INET, socket.SOCK_DGRAM
        )
        if recv_socket is None:
            recv_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            recv_socket.bind(("0.0.0.0", server_listen_port))
        self._recv_sock = recv_socket

        # Sender — destination filled in on enable_listen()
        self._sender = AudioStreamSender(
            source=source,
            socket_=self._send_sock,
            dest_host="0.0.0.0",
            dest_port=client_listen_port,
            samples_per_packet=samples_per_packet,
            thread_name="audio-capture",
        )
        # Receiver — listens on server_listen_port for client PTT audio
        self._receiver = AudioStreamReceiver(
            sink=sink,
            socket_=self._recv_sock,
            samples_per_packet=samples_per_packet,
            thread_name="audio-playback",
        )

        self._client_host: Optional[str] = None

    # ---- public control API ---------------------------------------------
    def enable_listen(self, client_host: str) -> None:
        """Start streaming mic audio to client_host:client_listen_port."""
        self._client_host = client_host
        self._sender.update_dest(client_host, self.client_listen_port)
        self._sender.start()

    def disable_listen(self) -> None:
        self._sender.stop()

    def enable_talk(self) -> None:
        """Start receiving client audio and routing to the amp."""
        self._receiver.start()

    def disable_talk(self) -> None:
        self._receiver.stop()

    def shutdown(self) -> None:
        self.disable_listen()
        self.disable_talk()
        for s in (self._send_sock, self._recv_sock):
            try:
                s.close()
            except OSError:
                pass

    # ---- introspection (for tests) --------------------------------------
    @property
    def listen_active(self) -> bool:
        return self._sender.is_running()

    @property
    def talk_active(self) -> bool:
        return self._receiver.is_running()
