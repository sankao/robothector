# Steam Deck Network Environment Research

## OS Overview

- SteamOS 3.x is **Arch Linux-based** with an **immutable (read-only) root filesystem**
- A/B partition scheme — system updates overwrite the inactive partition, wiping any system-level changes
- Two modes: **Gaming Mode** (default, full-screen Steam UI) and **Desktop Mode** (KDE Plasma, Konsole terminal)
- Native display: **1280x800**

## Networking

### mDNS / .local Resolution

**mDNS is unreliable on Steam Deck.** Valve has intentionally limited avahi/mDNS support:

- `avahi-daemon` exists but is actively disabled after reboots (symlink removed from systemd wants)
- `systemd-resolved` handles some mDNS but not consistently
- Resolving `.local` hostnames (e.g. `robothector.local`) **does not work out of the box**
- Workarounds exist but get wiped on SteamOS updates

**Implication: The UDP beacon discovery fallback is essential, not optional.** Can't rely on mDNS alone for Pi auto-detection from Steam Deck.

Workaround (fragile, survives until next OS update):
```bash
# Enable avahi
sudo steamos-readonly disable
sudo systemctl enable --now avahi-daemon
sudo steamos-readonly enable
```

### SSH

- **SSH client (`ssh`)** is available by default (part of openssh package in SteamOS)
- **SSH server (`sshd`)** is pre-installed but disabled; can be enabled in Desktop Mode
- `ssh pi@<ip-address>` works from Konsole in Desktop Mode
- SSH works from scripts launched in Gaming Mode too

### WiFi

- Standard WiFi (2.4GHz + 5GHz) via internal adapter
- No issues with TCP/UDP networking from non-Steam apps

## Package Installation

### System Packages (pacman)

- Root filesystem is read-only by default
- `sudo steamos-readonly disable` unlocks it, but **all pacman installs are wiped on SteamOS updates**
- Userspace pacman (install to `~/.root/`) survives updates but adds complexity
- **Recommendation**: Avoid system packages. Use pip in user home or flatpak.

### Python

- Python 3 is available on SteamOS (system python)
- `pip install --user <package>` installs to `~/.local/` which **persists across updates**
- pygame, websocket-client, requests all installable via pip

```bash
pip install --user pygame websocket-client requests
```

## Running the Client App

### Desktop Mode

- Launch from Konsole: `python3 client/main.py`
- Full access to filesystem, networking, terminal
- **Controller issue**: SDL 2.30.9+ broke Steam Deck controller detection in desktop mode for non-Steam apps
- Fix: configure Desktop Controller Layout to "Gamepad" template in Steam settings, or launch via Steam

### Gaming Mode (Recommended for Driving)

- Add the pygame app as a **Non-Steam Game** in Steam Library
- Create a launcher script:

```bash
#!/bin/bash
cd ~/robothector
python3 -m client.main
```

- Add script via: Steam Desktop Mode → Games → Add a Non-Steam Game
- Gaming Mode expects a visual window — pygame's fullscreen display satisfies this
- **Controller works properly** when launched through Steam in Gaming Mode (Steam Input active)
- Steam Input maps the built-in controls as an Xbox-like gamepad (SDL_GameController)

### Controller Mapping (when working)

Steam Deck controls map as standard SDL gamepad:
- Left stick: axes 0 (X) and 1 (Y)
- Right stick: axes 2 (X) and 3 (Y)
- L1/R1: buttons 4/5
- Triggers: axes 4 (L2) and 5 (R2)
- Back grips: accessible via Steam Input configuration

## Summary / Recommendations

| Concern | Recommendation |
|---------|---------------|
| Pi discovery | **UDP beacon is primary**, mDNS as bonus if avahi happens to work |
| Python packages | `pip install --user` (persists across updates) |
| Running the client | Add as Non-Steam Game, launch in Gaming Mode for best controller support |
| Controller input | Works via SDL_GameController when launched through Steam |
| Display | 1280x800 native, pygame fullscreen |

## Sources

- [mDNS forcefully disabled - Steam Community](https://steamcommunity.com/app/1675200/discussions/1/4040356791026913396/)
- [DNS .local no longer broadcasted - Steam Community](https://steamcommunity.com/app/1675200/discussions/1/5828254465007279012/)
- [Userspace pacman on Steam Deck](https://www.jeromeswannack.com/projects/2024/11/29/steamdeck-userspace-pacman.html)
- [SDL Steam Deck controller issue #11861](https://github.com/libsdl-org/SDL/issues/11861)
- [Non-Steam game controller layout - Steam Community](https://steamcommunity.com/app/1675200/discussions/1/3498761139323172659/)
- [Running shell scripts in Gaming Mode](https://gist.github.com/pudquick/981a3e495ffb5badc38e34d754873eb5)
- [Steam Deck SSH setup](https://gist.github.com/andygeorge/eee2825fa6446b629745ea92e862593a)
