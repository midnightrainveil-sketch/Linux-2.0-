#!/usr/bin/env bash
# Archive desktop installer for Arch Linux + Hyprland.
#
#   ./install.sh                 link the dotfiles, enable the services (safe to re-run)
#   ./install.sh --packages      also install the official packages (sudo pacman)
#   ./install.sh --g14           also set up the Zephyrus G14 GPU names (sudo, udev)
#   ./install.sh --plugins       build the archivebars title bars (run inside Hyprland)
#   ./install.sh --greeter       enable greetd + tuigreet to start Hyprland at boot (sudo)
#   ./install.sh --all           packages + g14 + link + services + greeter
#
# Existing files are moved to ~/.archive-backup/<date>/ before being replaced.
# The dotfiles are symlinked, so `git pull` in this folder updates your desktop.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
src="$repo/dotfiles"
backup="$HOME/.archive-backup/$(date +%Y%m%d-%H%M%S)"

say() { printf '\033[1m:: %s\033[0m\n' "$*"; }
warn() { printf '\033[33m!! %s\033[0m\n' "$*" >&2; }

want_packages=0 want_g14=0 want_plugins=0 want_greeter=0 want_link=1
for arg in "$@"; do
    case $arg in
        --packages) want_packages=1 ;;
        --g14) want_g14=1 ;;
        --plugins) want_plugins=1; want_link=0 ;;
        --greeter) want_greeter=1 ;;
        --all) want_packages=1; want_g14=1; want_greeter=1 ;;
        -h | --help) sed -n '2,13p' "$0"; exit 0 ;;
        *) warn "unknown option $arg"; exit 2 ;;
    esac
done

[[ $EUID -ne 0 ]] || { warn "run as your user, not root (sudo is used where needed)"; exit 1; }
[[ -f /etc/arch-release ]] || warn "this is written for Arch Linux; continuing anyway"

# ------------------------------------------------------------------ packages
if (( want_packages )); then
    say "installing packages"
    grep -vE '^\s*(#|$)' "$repo/packages/pacman.txt" | sudo pacman -S --needed -
fi

# ------------------------------------------------------------------ G14: stable GPU names for Hyprland
if (( want_g14 )); then
    say "Zephyrus G14: udev names for the GPUs (/dev/dri/amd-igpu, /dev/dri/nvidia-dgpu)"
    amd=$(lspci -d ::03xx | grep -i 'AMD' | head -n1 | cut -d' ' -f1 || true)
    nv=$(lspci -d ::03xx | grep -i 'NVIDIA' | head -n1 | cut -d' ' -f1 || true)
    rules=""
    [[ -n $amd ]] && rules+="KERNEL==\"card*\", KERNELS==\"0000:$amd\", SUBSYSTEM==\"drm\", SUBSYSTEMS==\"pci\", SYMLINK+=\"dri/amd-igpu\""$'\n'
    [[ -n $nv ]] && rules+="KERNEL==\"card*\", KERNELS==\"0000:$nv\", SUBSYSTEM==\"drm\", SUBSYSTEMS==\"pci\", SYMLINK+=\"dri/nvidia-dgpu\""$'\n'
    if [[ -n $rules ]]; then
        printf '%s' "$rules" | sudo tee /etc/udev/rules.d/90-archive-gpu-names.rules >/dev/null
        # no `udevadm trigger` here: re-announcing the GPUs to a running
        # Hyprland can take it down. The names appear at the next boot.
        sudo udevadm control --reload
        echo "   the names appear after the next reboot"
    else
        warn "no AMD / NVIDIA display controller found; skipped"
    fi
fi

# ------------------------------------------------------------------ dotfiles
link_file() { # link_file <repo file> <target>
    local from=$1 to=$2
    if [[ -L $to && $(readlink "$to") == "$from" ]]; then return; fi
    if [[ -e $to || -L $to ]]; then
        mkdir -p "$backup/$(dirname "${to#"$HOME"/}")"
        mv "$to" "$backup/${to#"$HOME"/}"
    fi
    mkdir -p "$(dirname "$to")"
    ln -s "$from" "$to"
}

if (( want_link )); then
    say "linking dotfiles into $HOME"
    own_wallpaper=0
    compgen -G "${XDG_CONFIG_HOME:-$HOME/.config}/archive/wallpaper.*" >/dev/null && own_wallpaper=1
    while IFS= read -r -d '' f; do
        rel=${f#"$src"/}
        # your own wallpaper (archive-wallpaper) is made right there: leave it
        if ((own_wallpaper)) && [[ $rel == .local/share/archive/plates/* ]]; then continue; fi
        link_file "$f" "$HOME/$rel"
    done < <(find "$src" \( -type f -o -type l \) -print0)
    # links left by files a newer version no longer has
    find "$HOME/.config" "$HOME/.local" -xtype l -lname "$src/*" -delete 2>/dev/null || true
    [[ -d $backup ]] && say "previous files kept in $backup"

    chmod +x "$src/.local/bin/"archive-*

    say "fonts"
    fc-cache -f >/dev/null 2>&1 || true

    say "state: day / night, grain"
    state="${XDG_STATE_HOME:-$HOME/.local/state}/archive"
    mkdir -p "$state" "$HOME/Pictures/Archive"
    [[ -f $state/grain ]] || echo on >"$state/grain"     # paper grain on windows (archive-grain)
    [[ -f $state/lamp ]] || echo on >"$state/lamp"       # the night desk lamp
    [[ -f $state/refresh ]] || echo 120 >"$state/refresh" # the panel's rate (archive-refresh)
    [[ -f $state/idle ]] || echo 5 >"$state/idle"         # minutes away before it locks (archive-idle)
    "$HOME/.local/bin/archive-mode" auto || true
    # make sure GTK / Qt / foot match even if the mode did not change
    "$HOME/.local/bin/archive-mode" "$("$HOME/.local/bin/archive-mode" status)" || true
    rm -f "$state/mode-hold"

    say "GTK and cursor settings"
    if command -v gsettings >/dev/null; then
        gsettings set org.gnome.desktop.interface font-name 'IBM Plex Sans 10' || true
        gsettings set org.gnome.desktop.interface monospace-font-name 'IBM Plex Mono 11' || true
        gsettings set org.gnome.desktop.interface icon-theme 'Archive' || true
        gsettings set org.gnome.desktop.interface cursor-theme 'Archive-Cursors' || true
        gsettings set org.gnome.desktop.interface cursor-size 32 || true
        gsettings set org.gnome.desktop.wm.preferences button-layout ':' || true
        gsettings set org.gnome.desktop.sound theme-name 'archive' || true
    fi

    say "services"
    systemctl --user daemon-reload || true
    systemctl --user enable --now archive-mode.timer || warn "could not enable archive-mode.timer (run again from your session)"
    if command -v systemctl >/dev/null && systemctl list-unit-files 2>/dev/null | grep -q '^bluetooth.service'; then
        sudo systemctl enable --now bluetooth.service || true
    fi
    sudo systemctl enable --now power-profiles-daemon.service 2>/dev/null || true

    if [[ $(getent passwd "$USER" | cut -d: -f7) != */zsh ]] && command -v zsh >/dev/null; then
        say "making zsh your shell"
        chsh -s "$(command -v zsh)" || warn "chsh failed; run: chsh -s $(command -v zsh)"
    fi
fi

# ------------------------------------------------------------------ greeter
if (( want_greeter )); then
    say "greetd + tuigreet (a typed login that starts Hyprland)"
    sudo tee /etc/greetd/config.toml >/dev/null <<'EOF'
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --time-format '%a %d %b  %H:%M' --remember --asterisks --asterisks-char x --greeting 'Archive. Signature required.' --cmd start-hyprland"
user = "greeter"
EOF
    sudo systemctl enable greetd.service
    warn "greetd takes over tty1 from the next boot; disable any other display manager first"
fi

# ------------------------------------------------------------------ title bars
if (( want_plugins )); then
    [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] || { warn "--plugins must run inside a Hyprland session"; exit 1; }
    say "building the archivebars title-bar plugin (hyprbars + ruled line + right glyph)"
    hyprpm disable hyprbars >/dev/null 2>&1 || true
    if "$HOME/.local/bin/archive-bars" build; then
        say "title bars built; Hyprland reloaded"
    else
        warn "archivebars did not build (log: ~/.cache/archive/archivebars/build.log)"
        warn "falling back to stock hyprbars: same bar, without the rule and the '-'"
        hyprpm update
        hyprpm add https://github.com/hyprwm/hyprland-plugins || true
        hyprpm enable hyprbars
        hyprpm reload -n
    fi
fi

say "done. Title bars and paper edges: ./install.sh --plugins (setup.sh does this for you)"
