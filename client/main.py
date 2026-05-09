"""Client main loop — pygame app with video, joystick, WebSocket, and audio.

Usage: uv run python -m client.main [--host HOST] [--ws-port PORT] [--video-port PORT] [--no-audio]

Audio control (when enabled):
  Y button = toggle listening to the robot's mic
  A button = push-to-talk (held = transmitting through the robot's amp)
"""

import argparse
import sys

import pygame

from client import joystick, ui
from client.network import NetworkClient
from client.video import VideoStream


def parse_args():
    parser = argparse.ArgumentParser(description="Robothector client")
    parser.add_argument("--host", default="robothector.local", help="Server hostname or IP")
    parser.add_argument("--ws-port", type=int, default=8765, help="WebSocket port")
    parser.add_argument("--video-port", type=int, default=5000, help="MJPEG video port")
    parser.add_argument("--windowed", action="store_true", help="Start in windowed mode")
    parser.add_argument("--no-audio", action="store_true",
                        help="Disable audio plane (skip mic + speaker setup)")
    return parser.parse_args()


def _make_audio_client(host: str):
    """Build an AudioClient. Falls back to fakes on machines without sounddevice."""
    from client.audio import AudioClient
    from protocol.audio_io import (
        FakeAudioSink,
        FakeAudioSource,
        SoundDeviceSink,
        SoundDeviceSource,
    )

    try:
        source = SoundDeviceSource()
        sink = SoundDeviceSink()
        # Probe by trying a no-op start/stop on the sink — start raises if
        # PortAudio is missing or no default device exists.
        sink.start()
        sink.stop()
        print("[main] audio: real sounddevice mic + speaker")
    except Exception as e:
        print(f"[main] audio: sounddevice unavailable ({e}); falling back to fakes")
        source = FakeAudioSource()
        sink = FakeAudioSink()

    return AudioClient(source=source, sink=sink, server_host=host)


def main():
    args = parse_args()

    pygame.init()

    flags = 0 if args.windowed else pygame.FULLSCREEN
    screen = pygame.display.set_mode((ui.SCREEN_W, ui.SCREEN_H), flags)
    pygame.display.set_caption("Robothector")
    clock = pygame.time.Clock()
    fullscreen = not args.windowed

    ui.init()
    joystick.init()

    network = NetworkClient(host=args.host, ws_port=args.ws_port)
    network.start()

    video = VideoStream(host=args.host, video_port=args.video_port)
    video.start()

    audio_client = None if args.no_audio else _make_audio_client(args.host)

    last_mode = ""
    last_listen = False
    last_talk = False

    print("[main] client started — Esc=quit, F11=fullscreen, A=PTT, Y=listen toggle")

    try:
        while True:
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    raise SystemExit
                elif event.type == pygame.KEYDOWN:
                    if event.key == pygame.K_ESCAPE:
                        raise SystemExit
                    elif event.key == pygame.K_F11:
                        fullscreen = not fullscreen
                        if fullscreen:
                            screen = pygame.display.set_mode(
                                (ui.SCREEN_W, ui.SCREEN_H), pygame.FULLSCREEN
                            )
                        else:
                            screen = pygame.display.set_mode((ui.SCREEN_W, ui.SCREEN_H))
                elif event.type in (
                    pygame.JOYBUTTONDOWN,
                    pygame.JOYBUTTONUP,
                    pygame.JOYDEVICEADDED,
                    pygame.JOYDEVICEREMOVED,
                ):
                    joystick.handle_event(event)

            input_data = joystick.get_input()
            network.send_drive(input_data["axis_x"], input_data["axis_y"])

            if input_data["mode"] != last_mode:
                network.send_mode(input_data["mode"])
                last_mode = input_data["mode"]

            # ---- audio listen toggle (Y button) ----
            if input_data["listen"] != last_listen:
                network.send_audio_listen(input_data["listen"])
                if audio_client is not None:
                    if input_data["listen"]:
                        audio_client.start_listening()
                    else:
                        audio_client.stop_listening()
                last_listen = input_data["listen"]

            # ---- audio push-to-talk (A button held) ----
            if input_data["talk"] != last_talk:
                network.send_audio_talk(input_data["talk"])
                if audio_client is not None:
                    if input_data["talk"]:
                        audio_client.start_talking()
                    else:
                        audio_client.stop_talking()
                last_talk = input_data["talk"]

            frame = video.get_frame()
            state = network.get_state()

            ui.render(
                screen, frame,
                state=state,
                input_data=input_data,
                connected=network.is_connected(),
                video_connected=video.is_connected(),
            )

            pygame.display.flip()
            clock.tick(30)

    except SystemExit:
        pass
    finally:
        print("[main] shutting down...")
        network.send_drive(0.0, 0.0)
        network.send_audio_listen(False)
        network.send_audio_talk(False)
        if audio_client is not None:
            audio_client.shutdown()
        network.stop()
        video.stop()
        joystick.cleanup()
        pygame.quit()
        print("[main] goodbye")


if __name__ == "__main__":
    main()
