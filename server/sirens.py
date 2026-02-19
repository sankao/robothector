"""Siren/audio module for emergency mode sounds.

Manages playback of WAV files via pygame.mixer:
  - reverse.wav (beeping when driving forward — "reversing" in emergency vehicle style)
  - firefighter.wav
  - ambulance.wav
"""

import os

_mixer_available = False
_sounds: dict = {}
_current_mode = ""

SOUND_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)))


def init():
    global _mixer_available
    try:
        import pygame.mixer
        pygame.mixer.init()
        _mixer_available = True
        _load_sounds()
        _log("sirens initialized")
    except Exception as e:
        _log(f"sirens unavailable: {e}")


def _load_sounds():
    import pygame.mixer
    for name in ("reverse", "firefighter", "ambulance"):
        path = os.path.join(SOUND_DIR, f"{name}.wav")
        if os.path.exists(path):
            _sounds[name] = pygame.mixer.Sound(path)
            _log(f"loaded {name}.wav")


def play_siren(mode: str):
    """Play siren for given mode. Mode: 'firefighter', 'ambulance', 'reverse', or '' to stop."""
    global _current_mode
    if mode == _current_mode:
        return
    stop_sirens()
    _current_mode = mode
    if _mixer_available and mode in _sounds:
        _sounds[mode].play(loops=-1)
        _log(f"playing {mode}")


def stop_sirens():
    global _current_mode
    if _mixer_available:
        for snd in _sounds.values():
            snd.stop()
    _current_mode = ""


def cleanup():
    stop_sirens()
    if _mixer_available:
        import pygame.mixer
        pygame.mixer.quit()
    _log("sirens cleaned up")


def _log(msg: str):
    print(f"[sirens] {msg}")
