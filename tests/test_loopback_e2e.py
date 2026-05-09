"""End-to-end loopback test.

Spawns a full AudioServer + AudioClient in the same process, both with
FakeAudioSource feeding distinct payloads, and asserts that:

  1. Audio sent by the server's FakeAudioSource arrives at the client's
     FakeAudioSink (i.e. the "operator hears the robot" path works
     end-to-end through serialise -> UDP -> deserialise -> jitter buffer
     -> sink).
  2. Audio sent by the client's FakeAudioSource arrives at the server's
     FakeAudioSink (i.e. the "operator talks to the robot" path).
  3. Both directions can run simultaneously without one starving the
     other.
  4. The round-trip latency is bounded.

This is the highest-fidelity test we can do without real audio hardware.
"""

from __future__ import annotations

import socket
import time

import pytest

from client.audio import AudioClient
from protocol.audio_io import FakeAudioSink, FakeAudioSource
from protocol.audio_packet import BYTES_PER_SAMPLE
from server.audio import AudioServer


def chunk(n_samples: int, fill: int = 0) -> bytes:
    return (fill.to_bytes(2, "little", signed=True)) * n_samples


def make_udp_socket() -> socket.socket:
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.bind(("127.0.0.1", 0))
    return s


@pytest.fixture
def loopback():
    """Build a paired AudioServer + AudioClient with ephemeral ports."""
    # Server side mic + speaker
    srv_src = FakeAudioSource()
    srv_sink = FakeAudioSink()

    # Client side mic + speaker
    cli_src = FakeAudioSource()
    cli_sink = FakeAudioSink()

    # Server sockets
    srv_send_sock = make_udp_socket()
    srv_recv_sock = make_udp_socket()
    srv_recv_port = srv_recv_sock.getsockname()[1]

    # Client sockets
    cli_send_sock = make_udp_socket()
    cli_recv_sock = make_udp_socket()
    cli_recv_port = cli_recv_sock.getsockname()[1]

    server = AudioServer(
        source=srv_src,
        sink=srv_sink,
        send_socket=srv_send_sock,
        recv_socket=srv_recv_sock,
        client_listen_port=cli_recv_port,
        server_listen_port=srv_recv_port,
        samples_per_packet=320,
    )
    client = AudioClient(
        source=cli_src,
        sink=cli_sink,
        server_host="127.0.0.1",
        send_socket=cli_send_sock,
        recv_socket=cli_recv_sock,
        client_listen_port=cli_recv_port,
        server_listen_port=srv_recv_port,
        samples_per_packet=320,
    )

    yield server, client, srv_src, srv_sink, cli_src, cli_sink

    client.shutdown()
    server.shutdown()


def wait_until(predicate, timeout: float = 3.0, poll_s: float = 0.02) -> bool:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if predicate():
            return True
        time.sleep(poll_s)
    return False


class TestServerToClient:
    def test_robot_mic_audio_reaches_operator_speaker(self, loopback) -> None:
        server, client, srv_src, _srv_sink, _cli_src, cli_sink = loopback
        # robot mic produces a known sequence
        srv_src._chunks = [chunk(320, fill=i) for i in range(8)]  # type: ignore[attr-defined]

        client.start_listening()
        server.enable_listen("127.0.0.1")

        # JitterBuffer needs target_depth=2 packets before first emit, plus
        # network/thread scheduling — wait for at least 5 chunks at the sink.
        assert wait_until(
            lambda: len(cli_sink.received) >= 5
        ), f"only got {len(cli_sink.received)} chunks at client sink"

        server.disable_listen()
        client.stop_listening()

        # Verify the original PCM data made it through.
        # The first emitted chunk is the lowest-seq packet (seq 0 -> fill 0).
        assert cli_sink.received[0] == chunk(320, fill=0)
        # The sequence should be in order (no shuffling on a quiet localhost).
        for i, payload in enumerate(cli_sink.received[:5]):
            assert payload == chunk(320, fill=i), f"chunk {i} mismatch"


class TestClientToServer:
    def test_operator_voice_reaches_robot_amp(self, loopback) -> None:
        server, client, _srv_src, srv_sink, cli_src, _cli_sink = loopback
        cli_src._chunks = [chunk(320, fill=10 + i) for i in range(8)]  # type: ignore[attr-defined]

        server.enable_talk()
        client.start_talking()

        assert wait_until(
            lambda: len(srv_sink.received) >= 5
        ), f"only got {len(srv_sink.received)} chunks at server sink"

        client.stop_talking()
        server.disable_talk()

        for i, payload in enumerate(srv_sink.received[:5]):
            assert payload == chunk(320, fill=10 + i)


class TestSimultaneousBidirectional:
    def test_both_directions_concurrent(self, loopback) -> None:
        """Drive listen + talk simultaneously; confirm neither starves."""
        server, client, srv_src, srv_sink, cli_src, cli_sink = loopback
        srv_src._chunks = [chunk(320, fill=i) for i in range(10)]  # type: ignore[attr-defined]
        cli_src._chunks = [chunk(320, fill=100 + i) for i in range(10)]  # type: ignore[attr-defined]

        # Bring up both directions
        client.start_listening()
        server.enable_listen("127.0.0.1")
        server.enable_talk()
        client.start_talking()

        assert wait_until(
            lambda: len(cli_sink.received) >= 4 and len(srv_sink.received) >= 4
        ), (
            f"insufficient progress: client_sink={len(cli_sink.received)} "
            f"server_sink={len(srv_sink.received)}"
        )

        # Both directions made progress
        assert len(cli_sink.received) >= 4
        assert len(srv_sink.received) >= 4
        # Distinct payloads — ensure we didn't crosstalk between directions
        assert cli_sink.received[0] == chunk(320, fill=0)        # robot -> operator
        assert srv_sink.received[0] == chunk(320, fill=100)      # operator -> robot

        client.stop_talking()
        server.disable_talk()
        server.disable_listen()
        client.stop_listening()


class TestRoundTripLatency:
    def test_first_chunk_arrives_within_300ms(self, loopback) -> None:
        """Wall-clock latency from enable to first chunk at sink, <300 ms.

        Target per audio-design.md is 300 ms total operator-to-operator;
        on localhost we should be well below that just for the
        sender-to-receiver leg.
        """
        server, client, srv_src, _srv_sink, _cli_src, cli_sink = loopback
        srv_src._chunks = [chunk(320, fill=i) for i in range(20)]  # type: ignore[attr-defined]

        t0 = time.monotonic()
        client.start_listening()
        server.enable_listen("127.0.0.1")
        assert wait_until(lambda: len(cli_sink.received) >= 1, timeout=1.0)
        first_chunk_ms = (time.monotonic() - t0) * 1000

        server.disable_listen()
        client.stop_listening()

        assert first_chunk_ms < 300, (
            f"first chunk took {first_chunk_ms:.0f} ms (expected < 300 ms on loopback)"
        )


class TestCleanShutdown:
    def test_stop_idempotent(self, loopback) -> None:
        server, client, *_ = loopback
        client.start_listening()
        server.enable_listen("127.0.0.1")
        server.enable_talk()
        client.start_talking()
        time.sleep(0.1)
        # double-stop must not crash
        client.stop_listening()
        client.stop_listening()
        client.stop_talking()
        client.stop_talking()
        server.disable_listen()
        server.disable_listen()
        server.disable_talk()
        server.disable_talk()


class TestPayloadIntegrity:
    def test_no_packet_corruption_over_many_chunks(self, loopback) -> None:
        """Send 50 distinct chunks; assert every received chunk matches a sent chunk."""
        server, client, srv_src, _srv_sink, _cli_src, cli_sink = loopback
        srv_src._chunks = [chunk(320, fill=i) for i in range(50)]  # type: ignore[attr-defined]
        expected = set(srv_src._chunks)  # type: ignore[attr-defined]

        client.start_listening()
        server.enable_listen("127.0.0.1")

        # let it run long enough to drain most packets
        wait_until(lambda: len(cli_sink.received) >= 30, timeout=4.0)

        server.disable_listen()
        client.stop_listening()

        # Every chunk that landed should be one we sent (no garbage),
        # and the count should be plausible (>= 25 out of 50).
        from protocol.audio_packet import silence_payload
        silence = silence_payload(320)
        for c in cli_sink.received:
            # silence chunks are inserted by the jitter buffer when the
            # sender source is exhausted (we scripted only 50 chunks); accept those too
            assert c in expected or c == silence, (
                f"unexpected chunk content: first 20 bytes {c[:20].hex()}"
            )
        non_silence = [c for c in cli_sink.received if c != silence]
        assert len(non_silence) >= 25, (
            f"only {len(non_silence)} non-silence chunks delivered out of 50"
        )

        # And received chunks should be a subset (in order) of sent — verify
        # no duplicates of the same fill
        non_silence_fills = [int.from_bytes(c[:2], "little", signed=True)
                             for c in non_silence]
        assert non_silence_fills == sorted(set(non_silence_fills))
