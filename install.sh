#!/usr/bin/env bash
# quickPaper installer — copies the picker to the standard locations.
set -eu

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

miss=()
for cmd in qs magick jq fzf pgrep; do
    command -v "$cmd" >/dev/null 2>&1 || miss+=("$cmd")
done
if ((${#miss[@]})); then
    echo "Missing dependencies: ${miss[*]}"
    echo "See the Dependencies section of README.md, then re-run this script."
    exit 1
fi

mkdir -p "$HOME/.config/quickshell/quickPaper" "$HOME/.local/bin"
cp "$here/quickshell/shell.qml" "$HOME/.config/quickshell/quickPaper/shell.qml"
install -m 755 "$here/scripts/quickpaper.sh" "$HOME/.local/bin/quickpaper.sh"

echo "Installed:"
echo "  ~/.config/quickshell/quickPaper/shell.qml"
echo "  ~/.local/bin/quickpaper.sh"
echo
echo "Next steps:"
echo "  1. Put wallpapers in ~/Pictures/Wallpapers (or export QUICKPAPER_DIR=/your/path)"
echo "  2. Bind quickpaper.sh to a key (see README: 'Launch by window manager')"
echo "  3. Run it once from a terminal to test:  ~/.local/bin/quickpaper.sh"
