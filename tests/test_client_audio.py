"""Tests for client.audio with FakeAudio* + loopback UDP on 127.0.0.1."""

from __future__ import annotations

import socket
import time

import pytest

from client.audio import AudioClient
from protocol import AudioPacket
from protocol.audio_io import FakeAudioSink, FakeAudioSource
from protocol.audio_packet import BYTES_PER_SAMPLE


def chunk(n_samples: int, fill: int = 0) -> bytes:
    return (fill.to_bytes(2, "little", signed=True)) * n_samples


def make_udp_socket() -> socket.socket:
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.bind(("127.0.0.1", 0))
    return s


@pytest.fixture
def client_setup():
    """Two ephemeral UDP sockets simulating the server end."""
    src = FakeAudioSource()
    sink = FakeAudioSink()

    client_send = make_udp_socket()
    client_recv = make_udp_socket()
    client_recv_port = client_recv.getsockname()[1]

    # the "server side" sockets (where the robot would be)
    server_recv = make_udp_socket()
    server_recv_port = server_recv.getsockname()[1]
    server_recv.settimeout(2.0)

    server_send = make_udp_socket()

    client = AudioClient(
        source=src,
        sink=sink,
        server_host="127.0.0.1",
        send_socket=client_send,
        recv_socket=client_recv,
        client_listen_port=client_recv_port,
        server_listen_port=server_recv_port,
        samples_per_packet=320,
    )

    yield client, src, sink, server_recv, server_send, client_recv_port

    client.shutdown()
    for s in (server_recv, server_send):
        try:
            s.close()
        except OSError:
            pass


class TestStartTalking:
    def test_capture_packets_arrive_at_server(self, client_setup) -> None:
        client, src, _sink, server_recv, _server_send, _crp = client_setup
        src._chunks = [chunk(320, fill=i) for i in range(5)]  # type: ignore[attr-defined]

        client.start_talking()
        packets: list[AudioPacket] = []
        deadline = time.monotonic() + 2.0
        while len(packets) < 5 and time.monotonic() < deadline:
            try:
                data, _ = server_recv.recvfrom(8192)
            except socket.timeout:
                break
            packets.append(AudioPacket.from_bytes(data))
        client.stop_talking()

        assert len(packets) == 5
        assert [p.seq for p in packets] == [0, 1, 2, 3, 4]
        for i, p in enumerate(packets):
            assert p.payload == chunk(320, fill=i)


class TestStartListening:
    def test_received_packets_reach_local_sink(self, client_setup) -> None:
        client, _src, sink, _server_recv, server_send, client_recv_port = client_setup

        client.start_listening()
        for i in range(4):
            pkt = AudioPacket(
                seq=i,
                timestamp_ms=i * 20,
                sample_count=320,
                payload=chunk(320, fill=i),
            )
            server_send.sendto(pkt.to_bytes(),
                               ("127.0.0.1", client_recv_port))
        deadline = time.monotonic() + 2.0
        while time.monotonic() < deadline:
            if sink.total_bytes >= 2 * 320 * BYTES_PER_SAMPLE:
                break
            time.sleep(0.02)
        client.stop_listening()

        total_samples = sum(len(c) for c in sink.received) // BYTES_PER_SAMPLE
        assert total_samples >= 320 * 2


class TestUpdateServerHost:
    def test_retargets_sender(self, client_setup) -> None:
        client, src, _sink, server_recv, _ss, _crp = client_setup
        # original host is 127.0.0.1 already; this test just confirms
        # the API doesn't blow up
        client.update_server_host("127.0.0.1")
        src._chunks = [chunk(320, fill=99)]  # type: ignore[attr-defined]
        client.start_talking()
        try:
            data, _ = server_recv.recvfrom(8192)
            pkt = AudioPacket.from_bytes(data)
            assert pkt.payload == chunk(320, fill=99)
        finally:
            client.stop_talking()


class TestIntrospection:
    def test_listening_property(self, client_setup) -> None:
        client, *_ = client_setup
        assert client.listening is False
        client.start_listening()
        assert client.listening is True
        client.stop_listening()
        assert client.listening is False

    def test_talking_property(self, client_setup) -> None:
        client, *_ = client_setup
        assert client.talking is False
        client.start_talking()
        time.sleep(0.05)
        assert client.talking is True
        client.stop_talking()
        assert client.talking is False
