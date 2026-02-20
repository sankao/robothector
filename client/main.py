"""Client main loop — pygame app with video, joystick, and WebSocket.

Usage: uv run python -m client.main [--host HOST] [--ws-port PORT] [--video-port PORT]
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
    return parser.parse_args()


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

    last_mode = ""

    print("[main] client started — press Escape to quit, F11 to toggle fullscreen")

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
                            screen = pygame.display.set_mode((ui.SCREEN_W, ui.SCREEN_H), pygame.FULLSCREEN)
                        else:
                            screen = pygame.display.set_mode((ui.SCREEN_W, ui.SCREEN_H))
                elif event.type == pygame.JOYBUTTONDOWN:
                    joystick.handle_button_event(event)

            input_data = joystick.get_input()
            network.send_drive(input_data["axis_x"], input_data["axis_y"])

            if input_data["mode"] != last_mode:
                network.send_mode(input_data["mode"])
                last_mode = input_data["mode"]

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
        network.stop()
        video.stop()
        joystick.cleanup()
        pygame.quit()
        print("[main] goodbye")


if __name__ == "__main__":
    main()
