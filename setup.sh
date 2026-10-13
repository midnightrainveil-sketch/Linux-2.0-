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
# Then reboot. Safe to run again at any time. The session you run it from is
# left as it is until then.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
home_repo="$(realpath -m "$HOME/archive")"
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

# ------------------------------------------------------------------ leave the running session alone
# Hyprland reloads its config the moment a file of it changes, and swapping a
# whole new desktop (or a freshly built plugin) into a live session can take
# it down. So the session you run this from keeps its old config until you
# log out; everything here takes effect at the next login.
if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && command -v hyprctl >/dev/null; then
    hyprctl eval 'hl.config({ misc = { disable_autoreload = true } })' >/dev/null 2>&1 || true
    sleep 1
fi
export ARCHIVE_NO_RELOAD=1   # archive-bars: build only, load at the next login

# ------------------------------------------------------------------ 1. keep the theme in ~/archive
# The dotfiles are linked, not copied, so the folder must stay put. If this
# was unpacked elsewhere (Downloads, say), it moves itself to ~/archive.
if [[ $here != "$home_repo" && -z ${ARCHIVE_SETUP_MOVED:-} ]]; then
    if [[ -e $home_repo && ! -f $home_repo/setup.sh ]]; then
        warn "$home_repo exists and is not this theme; move it aside and run again"
        exit 1
    fi
    say "copying the theme to $home_repo"
    mkdir -p "$home_repo"
    cp -a "$here/." "$home_repo/"
    ARCHIVE_SETUP_MOVED=1 exec "$home_repo/setup.sh" "$@"
fi

# ------------------------------------------------------------------ 2. packages
say "updating the system and installing packages (sudo pacman)"
# Arch is upgraded as a whole; installing onto stale package lists breaks things
if ! sudo pacman -Syu --noconfirm; then
    warn "the upgrade needs a decision; answering it yourself this time"
    sudo pacman -Syu || warn "the system upgrade reported a problem; see above"
fi
mapfile -t wanted < <(grep -vE '^\s*(#|$)' "$here/packages/pacman.txt")
repo_pkgs=() aur_pkgs=()
for p in "${wanted[@]}"; do
    if pacman -Si "$p" >/dev/null 2>&1; then repo_pkgs+=("$p"); else aur_pkgs+=("$p"); fi
done
if ! sudo pacman -S --needed --noconfirm "${repo_pkgs[@]}"; then
    # usually a question pacman will not answer by itself (a conflicting
    # package to replace, a provider to pick): ask you instead
    warn "pacman needs a decision; answering it yourself this time"
    sudo pacman -S --needed "${repo_pkgs[@]}" || warn "some packages failed to install; see above"
fi
if (( ${#aur_pkgs[@]} )); then
    helper=""
    for h in paru yay; do command -v $h >/dev/null && { helper=$h; break; }; done
    if [[ -z $helper ]] && ask "Not in the official repositories: ${aur_pkgs[*]}. Install the AUR helper yay to get them?"; then
        tmp=$(mktemp -d)
        if git clone -q https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin" && (cd "$tmp/yay-bin" && makepkg -si --noconfirm); then
            helper=yay
        else
            warn "could not install yay"
        fi
        rm -rf "$tmp"
    fi
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
    # the NVIDIA driver, built for the kernels you have (if it is not running)
    if lspci -d 10de: 2>/dev/null | grep -qiE 'vga|3d' && ! lsmod | grep -q '^nvidia '; then
        say "Zephyrus G14: the NVIDIA driver (Hybrid mode)"
        "$HOME/.local/bin/archive-rog" gpu || warn "the NVIDIA step failed; see docs/zephyrus-g14.md"
    fi
    # Quiet on battery, Balanced plugged in; no ROG Control notifications
    "$HOME/.local/bin/archive-rog" power || warn "could not set the power profiles; run archive-rog power"
    note "fan curves, battery limit and GPU modes: see docs/zephyrus-g14.md (asusctl, supergfxctl)"
fi

# ------------------------------------------------------------------ 5. the plugin
say "building the title bars and paper edges for your Hyprland (a minute or two)"
if "$HOME/.local/bin/archive-bars" update; then
    note "ready"
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
   Now reboot (sudo reboot). Until then this session keeps its old look.
   Then you will find the wallpaper, the three record cards on the right
   and a live terminal on the left.

   Drag the cards and the terminal anywhere; right-click a card to put it
   away; close the terminal if you like. The small card button in the bar
   (or Super + D) lays the desk out again.

   Super + Space  launcher          Super + N   day / night
   Super + Return terminal          Super + I   quick settings
   Everything else: ~/archive/GUIDE.md
EOF
