"""Tests for server.audio — capture/playback loops with fakes + real
loopback UDP sockets on 127.0.0.1."""

from __future__ import annotations

import socket
import time

import pytest

from protocol import AudioPacket, DEFAULT_SAMPLES_PER_PACKET
from protocol.audio_io import FakeAudioSink, FakeAudioSource
from protocol.audio_packet import BYTES_PER_SAMPLE
from server.audio import AudioServer


def chunk(n_samples: int, fill: int = 0) -> bytes:
    return (fill.to_bytes(2, "little", signed=True)) * n_samples


def make_udp_socket() -> socket.socket:
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.bind(("127.0.0.1", 0))  # ephemeral port
    return s


@pytest.fixture
def audio_setup():
    """Build an AudioServer with fakes + ephemeral loopback sockets."""
    src = FakeAudioSource()
    sink = FakeAudioSink()

    send_sock = make_udp_socket()           # server -> client
    server_recv_sock = make_udp_socket()    # client -> server (talk)
    server_recv_port = server_recv_sock.getsockname()[1]

    # the "client side" socket where capture packets land
    client_recv_sock = make_udp_socket()
    client_recv_port = client_recv_sock.getsockname()[1]
    client_recv_sock.settimeout(2.0)

    server = AudioServer(
        source=src,
        sink=sink,
        send_socket=send_sock,
        recv_socket=server_recv_sock,
        client_listen_port=client_recv_port,
        server_listen_port=server_recv_port,
        samples_per_packet=320,  # 20 ms — keeps tests fast
    )

    yield server, src, sink, client_recv_sock, server_recv_port

    server.shutdown()
    client_recv_sock.close()


class TestEnableListen:
    def test_capture_sends_packets_to_client_addr(self, audio_setup) -> None:
        server, src, _sink, client_recv, _port = audio_setup
        # 5 chunks of 320 samples each
        src._chunks = [chunk(320, fill=i) for i in range(5)]  # type: ignore[attr-defined]

        server.enable_listen("127.0.0.1")
        # collect packets that arrive at "client" within 2s
        packets: list[AudioPacket] = []
        deadline = time.monotonic() + 2.0
        while len(packets) < 5 and time.monotonic() < deadline:
            try:
                data, _ = client_recv.recvfrom(8192)
            except socket.timeout:
                break
            packets.append(AudioPacket.from_bytes(data))
        server.disable_listen()

        assert len(packets) == 5, f"only got {len(packets)} packets"
        # seq is monotonic from 0
        assert [p.seq for p in packets] == [0, 1, 2, 3, 4]
        # payloads survive the round trip
        for i, p in enumerate(packets):
            assert p.payload == chunk(320, fill=i)
            assert p.sample_count == 320

    def test_disable_listen_stops_thread(self, audio_setup) -> None:
        server, src, _sink, _client_recv, _port = audio_setup
        src._chunks = [chunk(320)] * 3  # type: ignore[attr-defined]
        server.enable_listen("127.0.0.1")
        time.sleep(0.1)
        assert server.listen_active is True
        server.disable_listen()
        assert server.listen_active is False

    def test_double_enable_is_idempotent(self, audio_setup) -> None:
        server, _src, _sink, _client_recv, _port = audio_setup
        server.enable_listen("127.0.0.1")
        server.enable_listen("127.0.0.1")  # no crash, no second thread
        # let it run a moment then teardown
        time.sleep(0.05)
        server.disable_listen()


class TestEnableTalk:
    def test_received_packets_reach_sink(self, audio_setup) -> None:
        server, _src, sink, _client_recv, server_port = audio_setup
        server.enable_talk()

        # send some packets from a fake "client" socket
        client_send = make_udp_socket()
        try:
            for i in range(4):
                pkt = AudioPacket(
                    seq=i,
                    timestamp_ms=i * 20,
                    sample_count=320,
                    payload=chunk(320, fill=i),
                )
                client_send.sendto(pkt.to_bytes(), ("127.0.0.1", server_port))
            # give the playback loop time to drain
            deadline = time.monotonic() + 2.0
            while time.monotonic() < deadline:
                if sink.total_bytes >= 2 * 320 * BYTES_PER_SAMPLE:
                    break
                time.sleep(0.02)
        finally:
            client_send.close()
        server.disable_talk()

        # JitterBuffer with target_depth=2 needs 2 packets queued before first emit;
        # given we sent 4, we should see at least 2 (and likely all 4 once it primes).
        total_samples = sum(len(c) for c in sink.received) // BYTES_PER_SAMPLE
        assert total_samples >= 320 * 2, (
            f"only got {total_samples} samples in sink — expected at least 640"
        )

    def test_malformed_packets_ignored(self, audio_setup) -> None:
        server, _src, sink, _client_recv, server_port = audio_setup
        server.enable_talk()

        client_send = make_udp_socket()
        try:
            # garbage packet — should be silently dropped
            client_send.sendto(b"this is not an audio packet", ("127.0.0.1", server_port))
            time.sleep(0.2)
        finally:
            client_send.close()
        server.disable_talk()

        # nothing should have reached the sink
        assert sink.received == []

    def test_disable_talk_stops_thread(self, audio_setup) -> None:
        server, _src, _sink, _client_recv, _port = audio_setup
        server.enable_talk()
        time.sleep(0.05)
        assert server.talk_active is True
        server.disable_talk()
        assert server.talk_active is False


class TestShutdown:
    def test_shutdown_idempotent(self, audio_setup) -> None:
        server, _src, _sink, _client_recv, _port = audio_setup
        server.enable_listen("127.0.0.1")
        server.enable_talk()
        server.shutdown()
        # second call should not raise
        server.shutdown()


class TestPayloadNormalisation:
    """Pad/truncate logic now lives on AudioStreamSender; reach in via the
    composed sender for these unit tests."""

    def test_short_payload_padded_with_silence(self, audio_setup) -> None:
        server, *_ = audio_setup
        short = b"\x01\x00" * 100  # 100 samples instead of 320
        normalised = server._sender._normalise(short)  # type: ignore[attr-defined]
        assert len(normalised) == 320 * BYTES_PER_SAMPLE
        assert normalised[:200] == short
        assert normalised[200:] == b"\x00" * (640 - 200)

    def test_long_payload_truncated(self, audio_setup) -> None:
        server, *_ = audio_setup
        long = b"\x01\x00" * 500  # 500 samples > 320
        normalised = server._sender._normalise(long)  # type: ignore[attr-defined]
        assert len(normalised) == 320 * BYTES_PER_SAMPLE
