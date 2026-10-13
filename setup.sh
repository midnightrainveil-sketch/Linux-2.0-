#!/usr/bin/env bash
# The Archive desktop, in one go, on an Arch Linux with Hyprland.
#
#   ./setup.sh            install everything, asking two questions
#   ./setup.sh --yes      the same, answering yes (typed login screen included)
#
# What it does, in order:
#   1. installs the packages (pacman; an AUR helper for anything pacman lacks)
#   2. copies itself to ~/archive if it was unpacked somewhere else
#   3. links the dotfiles into your home (your old files go to ~/.archive-backup)
#   4. on a Zephyrus G14, gives the GPUs stable names for Hyprland
#   5. builds the title-bar and paper-edge plugin for your Hyprland
#   6. optionally starts Hyprland at boot from a typed login screen
# Then log out and back in (or reboot). Safe to run again at any time.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
home_repo="$HOME/archive"
yes=0
[[ ${1:-} == --yes || ${1:-} == -y ]] && yes=1

say() { printf '\n\033[1m:: %s\033[0m\n' "$*"; }
note() { printf '   %s\n' "$*"; }
warn() { printf '\033[33m!! %s\033[0m\n' "$*" >&2; }
ask() { # ask "question" -> 0 for yes
    (( yes )) && return 0
    local a
    read -r -p "   $1 [y/N] " a
    [[ $a == [yY]* ]]
}

[[ $EUID -ne 0 ]] || { warn "run this as your own user, not root (it uses sudo where needed)"; exit 1; }
[[ -f /etc/arch-release ]] || warn "this is made for Arch Linux; continuing anyway"
command -v sudo >/dev/null || { warn "sudo is needed"; exit 1; }

# ------------------------------------------------------------------ 1. keep the theme in ~/archive
# The dotfiles are linked, not copied, so the folder must stay put. If this
# was unpacked elsewhere (Downloads, say), it moves itself to ~/archive.
if [[ $here != "$home_repo" ]]; then
    if [[ -e $home_repo && ! -f $home_repo/setup.sh ]]; then
        warn "$home_repo exists and is not this theme; move it aside and run again"
        exit 1
    fi
    say "copying the theme to $home_repo"
    mkdir -p "$home_repo"
    cp -a "$here/." "$home_repo/"
    exec "$home_repo/setup.sh" "$@"
fi

# ------------------------------------------------------------------ 2. packages
say "updating the system and installing packages (sudo pacman)"
# Arch is upgraded as a whole; installing onto stale package lists breaks things
sudo pacman -Syu --noconfirm || warn "the system upgrade reported a problem; see above"
mapfile -t wanted < <(grep -vE '^\s*(#|$)' "$here/packages/pacman.txt")
repo_pkgs=() aur_pkgs=()
for p in "${wanted[@]}"; do
    if pacman -Si "$p" >/dev/null 2>&1; then repo_pkgs+=("$p"); else aur_pkgs+=("$p"); fi
done
sudo pacman -S --needed --noconfirm "${repo_pkgs[@]}" || warn "some packages failed to install; see above"
if (( ${#aur_pkgs[@]} )); then
    helper=""
    for h in paru yay; do command -v $h >/dev/null && { helper=$h; break; }; done
    if [[ -n $helper ]]; then
        note "from the AUR with $helper: ${aur_pkgs[*]}"
        $helper -S --needed --noconfirm "${aur_pkgs[@]}" || warn "AUR install failed: ${aur_pkgs[*]}"
    else
        warn "not in your repositories, and no AUR helper (paru or yay) found: ${aur_pkgs[*]}"
        warn "install them yourself, then run ./setup.sh again"
    fi
fi
command -v qs >/dev/null || warn "Quickshell (qs) is missing: the bar, cards and wallpaper need it"

ver=$(Hyprland --version 2>/dev/null | grep -oE 'Hyprland [0-9]+\.[0-9]+' | grep -oE '[0-9]+\.[0-9]+' | head -n1)
if [[ -n $ver ]] && (( $(cut -d. -f2 <<<"$ver") < 55 )); then
    warn "Hyprland $ver is older than 0.55, which this config (hyprland.lua) needs: sudo pacman -Syu"
fi

# ------------------------------------------------------------------ 3. dotfiles, services
say "linking the theme into your home"
hypr_conf="$HOME/.config/hypr/hyprland.conf"
if [[ -e $hypr_conf && ! -L $hypr_conf ]]; then
    # an old hyprland.conf would compete with the theme's hyprland.lua
    keep="$HOME/.archive-backup/$(date +%Y%m%d-%H%M%S)/.config/hypr"
    mkdir -p "$keep"
    mv "$hypr_conf" "$keep/"
    note "your old hyprland.conf is in $keep (your own additions go in ~/.config/hypr/user.lua)"
fi
"$here/install.sh" || warn "linking reported a problem; see above"

# ------------------------------------------------------------------ 4. Zephyrus G14
model=$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)
if [[ $model == *Zephyrus*G14* || $model == *GA403* ]]; then
    say "Zephyrus G14 ($model): stable GPU names"
    "$here/install.sh" --g14 || warn "G14 step failed; see docs/zephyrus-g14.md"
    note "fan curves, battery limit and GPU modes: see docs/zephyrus-g14.md (asusctl, supergfxctl)"
fi

# ------------------------------------------------------------------ 5. the plugin
say "building the title bars and paper edges for your Hyprland (a minute or two)"
if "$HOME/.local/bin/archive-bars" build; then
    note "built"
else
    warn "the plugin did not build (log: ~/.cache/archive/archivebars/build.log)"
    note "everything else works; windows get plain straight edges until it builds."
    note "it retries at every login, or run: archive-bars build"
fi

# ------------------------------------------------------------------ 6. login screen
active_dm=$(systemctl list-unit-files --state=enabled 2>/dev/null | grep -oE '^(gdm|sddm|lightdm|ly|greetd)\.service' | head -n1 || true)
if [[ $active_dm == greetd.service ]]; then
    note "greetd is already your login screen"
elif [[ -n $active_dm ]]; then
    note "keeping your login screen ($active_dm); pick Hyprland there"
elif ask "Start Hyprland at boot from a typed login screen (greetd)?"; then
    "$HOME/archive/install.sh" --greeter || warn "greeter step failed"
fi

say "done"
cat <<'EOF'
   Log out and back in to Hyprland (or reboot). You will find the wallpaper,
   the three record cards on the right and a live terminal on the left.

   Drag the cards and the terminal anywhere; right-click a card to put it
   away; close the terminal if you like. The small card button in the bar
   (or Super + D) lays the desk out again.

   Super + Space  launcher          Super + N   day / night
   Super + Return terminal          Super + I   quick settings
   Everything else: ~/archive/GUIDE.md
EOF
