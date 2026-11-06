#!/usr/bin/env bash
# quickPaper — wallpaper carousel picker (Quickshell overlay), images only.
# Toggle: a second run while the picker is open closes it.

set -u

QML="$HOME/.config/quickshell/quickPaper/shell.qml"
if pid=$(pgrep -f "[q]s -p $QML"); then kill $pid; exit 0; fi

# ── which wallpaper backend will the picker talk to? ──
detect_backend() {
    if command -v noctalia >/dev/null 2>&1; then echo noctalia; return; fi
    case "${XDG_CURRENT_DESKTOP:-}" in
        *HYPRLAND*) echo hyprpaper; return;;
        *SWAY*)     echo swaybg;   return;;
    esac
    if command -v hyprctl >/dev/null 2>&1 && hyprctl monitors -j 2>/dev/null | grep -q monitor; then
        echo hyprpaper
    elif command -v swaymsg >/dev/null 2>&1 && swaymsg -t get_outputs >/dev/null 2>&1; then
        echo swaybg
    else
        echo generic
    fi
}
BACKEND=$(detect_backend)

# ── focused output (the carousel opens on the screen you are using) ──
focused_output() {
    case "$BACKEND" in
        noctalia) umbriel workspaces --json 2>/dev/null | jq -r '.[] | select(.focused) | .output' | head -1;;
        hyprpaper) hyprctl activewindow -j 2>/dev/null | jq -r '.monitor' 2>/dev/null;;
        swaybg)    swaymsg -t get_tree 2>/dev/null | jq -r '.nodes[].nodes[]?.nodes[]? | select(.focused) | .output' 2>/dev/null | head -1;;
    esac
}
ECRAN=$(focused_output)

# ── wallpaper directory (override with QUICKPAPER_DIR) ──
MINI="$HOME/.cache/quickpaper/miniatures"; mkdir -p "$MINI"
DIR="${QUICKPAPER_DIR:-$HOME/Pictures/Wallpapers}"

# ── list + 720px thumbnail cache (only new/changed files are generated, in parallel) ──
RUN="${XDG_RUNTIME_DIR:-/tmp}"
LISTE="$RUN/quickpaper-liste"; : > "$LISTE.tmp"; afaire=()
shopt -s nullglob nocaseglob
for f in "$DIR"/*.{jpg,jpeg,png,webp,avif}; do
  b=$(basename "${f%.*}"); m="$MINI/$b.jpg"
  [[ -s "$m" && "$m" -nt "$f" ]] || afaire+=("$f")
  nom=${b#[0-9][0-9]-}; nom=${nom//[-_]/ }
  printf '%s\t%s\t%s\n' "$nom" "$f" "$m" >> "$LISTE.tmp"
done
sort -f -t$'\t' -k2,2 "$LISTE.tmp" > "$LISTE"; rm -f "$LISTE.tmp"
if (( ${#afaire[@]} )); then
  printf '%s\0' "${afaire[@]}" | xargs -0 -P"$(nproc)" -I{} bash -c '
    f="$1"; b=$(basename "${f%.*}")
    magick "$f[0]" -thumbnail 720x405^ -gravity center -extent 720x405 -quality 85 "$2/$b.jpg"' _ {} "$MINI"
fi

# ── env consumed by the QML ──
cur=""
[[ "$BACKEND" == noctalia ]] && cur=$(noctalia msg wallpaper-get 2>/dev/null | head -1)
export QUICKPAPER_CURRENT="$cur" QUICKPAPER_ECRAN="$ECRAN" QUICKPAPER_LISTE="$LISTE" QUICKPAPER_BACKEND="$BACKEND"
# optional: color the UI from a theme (leave empty for the default accent)
export QUICKPAPER_ACCENT="${QUICKPAPER_ACCENT:-$(awk '/^active_border_color/{print $2}' ~/.config/kitty/themes/noctalia.conf 2>/dev/null)}"

qs -p "$QML" >/dev/null 2>&1     # blocking: qs quits when the QML calls Qt.quit()
