#!/bin/bash
# Run a theme's shell in the real Quickshell under a headless sway
# (1920x1200, the G14's logical size) and take screenshots.
#
#   STEPS=steps.sh docs/harness/run.sh <theme-id>      (MODE=night for the night sheet)
#
# The theme is put in place in a scratch home with ultra-theme, exactly as
# on the laptop. STEPS is a file of shell lines run once the shell is up:
#   shot name.png 20          wait 20 s, screenshot to $Q/name.png (the first
#                             needs about 20 s: software rendering is slow)
#   ipc shell catalogue       qs ipc call ... (log: $Q/out/ipc.log)
# Read $Q/out/qs.log afterwards: QML errors are there. Hyprland itself is
# not here: workspaces, windows and the title-bar plugin cannot be tested.
set -u
Q=${Q:-/tmp/qsreal}
REPO="$(cd "$(dirname "$(readlink -f "$0")")/../.." && pwd)"
THEME=${1:-archive}
if [ -z "${QS_INNER:-}" ]; then
    export QS_INNER=1
    exec dbus-run-session -- "$0" "$THEME"
fi
OUT=$Q/out
mkdir -p "$OUT"; rm -f "$OUT"/*.log "$OUT"/*.txt

export HOME=$Q/home USER=atlas
export XDG_CONFIG_HOME=$HOME/.config XDG_DATA_HOME=$HOME/.local/share XDG_STATE_HOME=$HOME/.local/state XDG_CACHE_HOME=$HOME/.cache
export XDG_RUNTIME_DIR=$Q/rt
rm -rf "$XDG_RUNTIME_DIR" "$HOME"; mkdir -p "$XDG_RUNTIME_DIR" "$HOME" "$XDG_CACHE_HOME"; chmod 700 "$XDG_RUNTIME_DIR"
python3 "$REPO/core/home/.local/bin/ultra-theme" core
python3 "$REPO/core/home/.local/bin/ultra-theme" apply "$THEME"
mkdir -p "$XDG_STATE_HOME/ultra/$THEME"; echo "${MODE:-day}" >"$XDG_STATE_HOME/ultra/$THEME/mode"
CFG=$HOME/.config/quickshell

export WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 WLR_RENDERER=pixman
unset WAYLAND_DISPLAY DISPLAY
sway -c "$Q/sway.conf" >"$OUT/sway.log" 2>&1 &
SWAYPID=$!
for i in $(seq 50); do ls "$XDG_RUNTIME_DIR"/wayland-* >/dev/null 2>&1 && break; sleep 0.1; done
export WAYLAND_DISPLAY=$(basename "$(ls "$XDG_RUNTIME_DIR"/wayland-? | head -1)")
export SWAYSOCK=$(ls "$XDG_RUNTIME_DIR"/sway-ipc.*.sock | head -1)
swaymsg output HEADLESS-1 mode 1920x1200 >/dev/null 2>&1

export QT_QPA_PLATFORM=wayland LANG=C.UTF-8 LC_ALL=C.UTF-8 LIBGL_ALWAYS_SOFTWARE=1
export __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/50_mesa.json
export QT_PLUGIN_PATH=$Q/env/lib/qt6/plugins QML_IMPORT_PATH=$Q/env/lib/qt6/qml QML2_IMPORT_PATH=$Q/env/lib/qt6/qml
export FONTCONFIG_FILE=$Q/env/etc/fonts/fonts.conf
export PATH=$HOME/.local/bin:$PATH
QS=$Q/inst/bin/quickshell

shot() { sleep "$2"; grim "$Q/$1" && echo "screenshot: $Q/$1"; }
ipc() { echo "\$ qs ipc call $*" >>"$OUT/ipc.log"; "$QS" -p "$CFG" ipc call "$@" >>"$OUT/ipc.log" 2>&1; echo "  exit=$?" >>"$OUT/ipc.log"; }

"$QS" -p "$CFG" >"$OUT/qs.log" 2>&1 &
QSPID=$!
sleep 5
. "${STEPS:?STEPS=<file of shot / ipc lines>}"
kill $QSPID $SWAYPID 2>/dev/null; wait 2>/dev/null; exit 0
