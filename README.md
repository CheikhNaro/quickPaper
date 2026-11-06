# quickPaper

A keyboard-driven wallpaper carousel for Wayland, built on [Quickshell](https://quickshell.out-of-focus.com/).
One keybind opens a full-screen overlay: a slanted carousel of your wallpaper folder with live fuzzy
search (fzf), `Enter` applies instantly, the overlay stays open so you can keep browsing, `Esc` closes.

- 720px thumbnail cache — only new/changed files are regenerated, in parallel
- Video files (mp4/webm/mkv/mov/gif) show a `▶ LIVE` badge and are **played with
  [mpvpaper](https://github.com/GhostNaN/mpvpaper)** — one instance per output, restarted on each pick
- Opens on the monitor you are focused on
- Re-running the launcher while the overlay is open closes it (toggle)
- Backend auto-detection: Noctalia, Hyprland (hyprpaper) or swaybg

## Dependencies

| Tool | Used for |
|---|---|
| `quickshell` (`qs`) | the overlay UI itself |
| `imagemagick` (`magick`) | thumbnail generation |
| `ffmpeg` | poster frames from video wallpapers |
| `jq` | JSON parsing (lists, focused output) |
| `fzf` | fuzzy filtering of the wallpaper list |
| `mpvpaper` (pulls in `mpv`) | **optional** — required to actually play video/animated wallpapers |
| `util-linux` (`pgrep`) | toggle detection |
| `noto-sans` + a **Material Design Icons** Nerd Font variant | UI fonts. The search field draws one MDI glyph, `󰍉`, so plain FontAwesome-only fonts show a box; `JetBrainsMono Nerd Font` (or any `…-Nerd Font` with MDI) works. Edit `mono`/`sans` in shell.qml for a different one. |

### Fedora

```sh
sudo dnf install quickshell ImageMagick ffmpeg-free jq fzf util-linux google-noto-sans-fonts
# optional, for video wallpapers (COPR build; mpvpaper is not in the stable Fedora repos yet):
sudo dnf install 'dnf-command(copr)'
sudo dnf copr enable lionheartp/Hyprland && sudo dnf install mpvpaper
# Nerd Font with MDI glyphs (needed for the 󰍉 search icon): install a "Nerd Font" patch
# from https://www.nerdfonts.com (e.g. JetBrainsMono Nerd Font) into ~/.local/share/fonts
```

`quickshell` is in Fedora repos since Fedora 42; on older releases build the `quickshell` AUR-equivalent
or use the COPR. The packaged binary is `qs`.

### Debian / Ubuntu

```sh
sudo apt install imagemagick ffmpeg jq fzf util-linux fonts-noto
# optional, for video wallpapers (Debian 12 / Ubuntu 24.04 and newer):
sudo apt install mpvpaper
# quickshell is not in Debian repos: use the official PPA or build from source:
#   https://github.com/quickshell/quickshell (CI artifacts / cmake build with qt6-base, qt6-declarative, qt6-wayland)
sudo apt install libqt6wayland6 qt6-declarative-dev qt6-base-dev wayland-protocols
```

### Arch

```sh
sudo pacman -S quickshell imagemagick ffmpeg jq fzf util-linux noto-fonts ttf-nerd-fonts-symbols mpvpaper
```

(`quickshell` is in extra since 2024; otherwise `quickshell-git` from the AUR.)

## Install

```sh
git clone https://github.com/CheikhNaro/quickPaper
cd quickPaper
./install.sh
```

`install.sh` checks the dependencies, then copies:

```
quickshell/shell.qml    →  ~/.config/quickshell/quickPaper/shell.qml
scripts/quickpaper.sh   →  ~/.local/bin/quickpaper.sh
```

Put your wallpapers in `~/Pictures/Wallpapers` (or export `QUICKPAPER_DIR=/your/path` before launching).

### Supported formats

Images: `jpg` `jpeg` `png` `webp` `avif` — Videos/animated: `mp4` `webm` `mkv` `mov` `gif`
(videos get a `▶ LIVE` badge, an ffmpeg poster frame in the carousel, and are played by **mpvpaper**).

> **Tip:** prefer light formats — `webp` (~10× smaller) and `avif` (~2–3× smaller than webp)
> load and thumbnail almost instantly, while large `png` wallpapers make the thumbnail pass and
> the first open noticeably slower. Reserve `png` for pixel-art/wallpaper packs that need it.

## Launch, depending on your window manager

The launcher is the same everywhere — only the keybind declaration changes.

### Umbriel / Noctalia (native support)

Both backends are auto-detected: `noctalia msg wallpaper-set` applies images and the current
wallpaper is highlighted on open; videos go through mpvpaper (Noctalia's `wallpaper-set` does
not play them).

```toml
# ~/.config/umbriel/config.toml
[keybinds]
"Mod+W" = { action = "spawn ~/.local/bin/quickpaper.sh", repeat = false }
```

### Hyprland (hyprpaper)

`hyprpaper` must be running (autostart `exec-once = hyprpaper`). The picker sends
`hyprpaper -l` (load) then `hyprpaper -s` (set) to every active monitor for images; videos are
played by mpvpaper directly, so hyprpaper's animation limits do not apply.

```ini
# hyprland.conf
bind = SUPER, W, exec, ~/.local/bin/quickpaper.sh
```

### Sway / wlroots compositors (swaybg)

The picker kills previous `swaybg` instances and spawns one per output for images;
videos again go through mpvpaper.

```
bindsym Mod4+w exec ~/.local/bin/quickpaper.sh
```

### Any other Wayland compositor

Bind `~/.local/bin/quickpaper.sh` wherever you bind keys. The picker requests exclusive
keyboard focus and an overlay layer via `ext-layer-shell`, which every wlroots-based compositor
supports. To use a different wallpaper daemon (kanso, xdg-desktop-portal wallpapers…), add a
branch in `setWallpaper()` at the top of `shell.qml` — it is a one-liner per daemon.

## Usage

| Key | Action |
|---|---|
| type anything | fuzzy-search the list (fzf scoring) |
| `←` `→` / `Tab` | previous / next card |
| `PgUp` `PgDn` | jump 3 cards |
| `Home` `End` | first / last |
| mouse wheel | scroll the carousel |
| hover / click | select / apply a card |
| `Enter` | apply the selected wallpaper, overlay stays open |
| `Esc` | close (what you last applied stays applied) |

The first opening animates the carousel scrolling to your current wallpaper; on Noctalia the
matching card starts centered.

## Configuration

Everything is env-driven in `scripts/quickpaper.sh`:

| Variable | Default | Meaning |
|---|---|---|
| `QUICKPAPER_DIR` | `~/Pictures/Wallpapers` | wallpaper folder |
| `QUICKPAPER_BACKEND` | auto-detected | `noctalia` / `hyprpaper` / `swaybg` / `generic` |
| `QUICKPAPER_ACCENT` | `#58d6f7` | UI accent color (the script tries your kitty Noctalia theme first) |

Tuning the carousel in `shell.qml` (top `readonly property` block):

| Property | Default | Meaning |
|---|---|---|
| `largeurActive` | 550 | width of the current card |
| `largeurTranche` | 250 | width of the neighbours (also the scroll step) |
| `hauteur` | 300 | row height |
| `pente` | 0.25 | slant of the frames (0 = straight rectangles) |
| `sautRapide` | 3 | PgUp/PgDn jump size |

Thumbnails live in `~/.cache/quickpaper/miniatures` — delete the folder to force a rebuild.

## Notes & known limits

- Video playback needs `mpvpaper` installed; without it a video pick is a silent no-op
  (the poster frame in the carousel still shows).
- mpvpaper 1.9 quirks the picker already handles: the outputs are **one quoted positional
  list** (`mpvpaper -f 'DP-1 HDMI-A-1' video`; `-o` is mpv options — the picker passes
  `-o "loop"`), auto-pause/stop (`-p`/`-s`)
  freezes the video behind normal windows, and SIGTERM/SIGINT are ignored — stop it with
  `pkill -9 -x mpvpaper` (mpv dies with it).
- "Centered on the current wallpaper" is only known on Noctalia (`wallpaper-get`); elsewhere the
  carousel starts on the first card.
- SDDM mirroring (`sync-sddm-wallpaper`) is intentionally not shipped; if you have such a script,
  add it back at the end of `setWallpaper()` in your local copy.
- The overlay takes exclusive keyboard focus: on compositors that refuse it to layer surfaces you
  browse with the mouse only.
