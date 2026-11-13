#!/usr/bin/env bash
# The desktop, in one go, on an Arch Linux with Hyprland.
#
#   ./setup.sh            install everything, asking two questions
#   ./setup.sh --yes      the same, answering yes (typed login screen included)
#
# What is where (everything lives in ~/ultra):
#   core/            the machine: screens, GPUs, Wi-Fi, ROS, updates, the
#                    ultra-* commands that are not about looks
#   themes/<id>/     one folder per desktop theme, each complete in itself
#                    (archive, night-service, viewfinder, any you add)
# Only the chosen theme's files are linked into your home (ultra-theme).
#
# What it does, in order:
#   1. copies itself to ~/ultra if it was unpacked somewhere else
#   2. links the machine's files and the chosen theme into your home (files
#      of yours in the way go to ~/.ultra-backup); an older install in
#      ~/archive is moved over, with your settings
#   3. installs the packages, the machine's and each theme's (pacman; an AUR
#      helper for anything pacman lacks)
#   4. on a Zephyrus G14, gives the GPUs stable names for Hyprland
#   5. builds each theme's icons and title-bar plugin for your Hyprland
#   6. optionally starts Hyprland at boot from a typed login screen
# Then reboot. Safe to run again at any time. Nothing here depends on the
# kernel: it serves linux and linux-lts alike.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
home_repo="$(realpath -m "$HOME/ultra")"
yes=0
[[ ${1:-} == --yes || ${1:-} == -y ]] && yes=1
config="${XDG_CONFIG_HOME:-$HOME/.config}"
state="${XDG_STATE_HOME:-$HOME/.local/state}"
data="${XDG_DATA_HOME:-$HOME/.local/share}"
bin="$HOME/.local/bin"

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
export ULTRA_NO_RELOAD=1   # ultra-bars, ultra-mode: no reload now, the next login has it

# ------------------------------------------------------------------ 1. keep it all in ~/ultra
# The files are linked, not copied, so the folder must stay put. If this was
# unpacked elsewhere (Downloads, a temporary folder), it copies itself to
# ~/ultra: the machine's part and every theme it ships are replaced whole
# (no stale files); themes of your own in ~/ultra/themes are left alone.
swap_in() { # swap_in <from> <to>: replace a folder in one step
    rm -rf "$2.new" "$2.old"
    cp -a "$1" "$2.new" || return 1
    [[ -e $2 ]] && mv "$2" "$2.old"
    mv "$2.new" "$2" && rm -rf "$2.old"
}
if [[ $here != "$home_repo" && -z ${ULTRA_SETUP_MOVED:-} ]]; then
    if [[ -e $home_repo && ! -f $home_repo/setup.sh ]]; then
        warn "$home_repo exists and is not this desktop; move it aside and run again"
        exit 1
    fi
    say "copying to $home_repo"
    mkdir -p "$home_repo/themes"
    for d in core docs; do swap_in "$here/$d" "$home_repo/$d" || { warn "could not copy $d"; exit 1; }; done
    for t in "$here"/themes/*/; do
        t=${t%/}
        swap_in "$t" "$home_repo/themes/${t##*/}" || { warn "could not copy the theme ${t##*/}"; exit 1; }
    done
    find "$here" -maxdepth 1 -type f -exec cp -a {} "$home_repo/" \;
    cp -a "$here/themes/README.md" "$home_repo/themes/" 2>/dev/null || true
    date +%s >"$home_repo/.stamp"      # ultra-theme: the files changed, link again
    ULTRA_SETUP_MOVED=1 exec "$home_repo/setup.sh" "$@"
fi
[[ -f $here/.stamp ]] || date +%s >"$here/.stamp"

# ------------------------------------------------------------------ 2. into your home
# ultra-theme does the linking; it is a python script
command -v python3 >/dev/null || sudo pacman -S --needed --noconfirm python || { warn "python is needed"; exit 1; }
ultra_theme() { python3 "$here/core/home/.local/bin/ultra-theme" "$@"; }

# ---- an older install (~/archive, the archive-* commands): your settings
# and choices carried over, its links taken out, the folder kept as a backup
old_repo="$HOME/archive"
if [[ -d $old_repo/dotfiles && ! -f $config/ultra/.moved-from-archive ]]; then
    say "moving the older install (~/archive) over"
    mkdir -p "$config/ultra" "$state/ultra/archive" "$state/ultra/night-service"
    oc="$config/archive" os="$state/archive"
    for f in theme card-desk-only icc ros rviz-setups; do
        [[ -e $oc/$f && ! -e $config/ultra/$f ]] && cp -a "$oc/$f" "$config/ultra/$f"
    done
    # (the wallpaper of your own was the herbarium's sheet)
    for f in "$oc"/wallpaper.*; do [[ -f $f ]] && mkdir -p "$config/ultra/archive" && cp -a "$f" "$config/ultra/archive/"; done
    if [[ -d $os ]]; then
        for f in "$os"/*; do
            [[ -e $f ]] || continue
            case ${f##*/} in
                # the machine's: the panel's rate, brightness, the microphone, restore points
                refresh | brightness* | gamma | backlight-* | mic-tone | snapshots-off)
                    [[ -e $state/ultra/${f##*/} ]] || cp -a "$f" "$state/ultra/" ;;
                # the look's: day or night, grain, the desk as you laid it out (each theme its own copy)
                *)  for t in archive night-service; do
                        [[ -e $state/ultra/$t/${f##*/} ]] || cp -a "$f" "$state/ultra/$t/"
                    done ;;
            esac
        done
    fi
    systemctl --user disable --now archive-mode.timer >/dev/null 2>&1 || true
    # its links, wherever they were, and the folders they leave empty
    for d in "$config"/{hypr,quickshell,archive,foot,fastfetch,gtk-3.0,gtk-4.0,qt6ct,fontconfig,zsh,systemd,pipewire} \
             "$bin" "$data"/{archive,applications,fonts,icons,sounds} "$HOME/Templates"; do
        [[ -d $d ]] || continue
        find "$d" -type l -lname "$old_repo/dotfiles/*" -delete 2>/dev/null || true
        find "$d" -mindepth 1 -type d -empty -delete 2>/dev/null || true
    done
    [[ -L $HOME/.zshenv && $(readlink "$HOME/.zshenv") == "$old_repo/dotfiles/"* ]] && rm -f "$HOME/.zshenv"
    # the ROS and RViz launcher entries: the command's new name
    for n in ros rviz; do
        f="$data/applications/archive-$n.desktop"
        [[ -f $f ]] && sed 's|/archive-ros|/ultra-ros|g' "$f" >"$data/applications/ultra-$n.desktop" && rm -f "$f"
    done
    # what is left of it (your own files, old state, caches), out of the way
    keep="$HOME/.ultra-backup/archive-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$keep"
    [[ -d $oc ]] && mv "$oc" "$keep/config" 2>/dev/null
    [[ -d $os ]] && mv "$os" "$keep/state" 2>/dev/null
    [[ -d $data/archive ]] && mv "$data/archive" "$keep/share" 2>/dev/null
    rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/archive"
    mv "$old_repo" "$keep/archive" 2>/dev/null || warn "could not move $old_repo aside; delete it yourself"
    touch "$config/ultra/.moved-from-archive"
    note "the old folder and settings are kept in $keep (delete it when all is well)"
fi

say "linking into your home: the machine's files, and the theme"
hypr_conf="$config/hypr/hyprland.conf"
if [[ -e $hypr_conf && ! -L $hypr_conf ]]; then
    # an old hyprland.conf would compete with hyprland.lua
    keep="$HOME/.ultra-backup/$(date +%Y%m%d-%H%M%S)/.config/hypr"
    mkdir -p "$keep"
    mv "$hypr_conf" "$keep/"
    note "your old hyprland.conf is in $keep (your own additions go in ~/.config/hypr/user.lua)"
fi
mkdir -p "$config/ultra" "$state/ultra"
[[ -f $state/ultra/refresh ]] || echo auto >"$state/ultra/refresh"   # the panel's rate: 120 Hz plugged in, 60 on battery (ultra-refresh)
ultra_theme core || { warn "could not link the machine's files"; exit 1; }
# the theme in place stays (a new choice is for the next login, as ever)
theme=$(ultra_theme current)
ultra_theme apply "$theme" --force || { warn "could not link the theme"; exit 1; }
theme=$(ultra_theme current)
note "theme: $theme"
export PATH="$bin:$PATH"
fc-cache -f >/dev/null 2>&1 || true

# ------------------------------------------------------------------ 3. packages
say "updating the system and installing packages (sudo pacman)"
# Arch is upgraded as a whole; installing onto stale package lists breaks things
if ! sudo pacman -Syu --noconfirm; then
    warn "the upgrade needs a decision; answering it yourself this time"
    sudo pacman -Syu || warn "the system upgrade reported a problem; see above"
fi
# the machine's, and those of every theme kept (themes/<id>/packages.txt)
mapfile -t wanted < <(cat "$here/core/packages/pacman.txt" "$here"/themes/*/packages.txt 2>/dev/null | grep -vE '^\s*(#|$)' | sort -u)
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
command -v qs >/dev/null || warn "Quickshell (qs) is missing: the themes' shells need it"

ver=$(Hyprland --version 2>/dev/null | grep -oE 'Hyprland [0-9]+\.[0-9]+' | grep -oE '[0-9]+\.[0-9]+' | head -n1)
if [[ -n $ver ]] && (( $(cut -d. -f2 <<<"$ver") < 55 )); then
    warn "Hyprland $ver is older than 0.55, which this config (hyprland.lua) needs: sudo pacman -Syu"
fi

# ------------------------------------------------------------------ services, defaults
say "services"
systemctl --user daemon-reload || true
if systemctl list-unit-files 2>/dev/null | grep -q '^bluetooth.service'; then
    sudo systemctl enable --now bluetooth.service || true
fi
sudo systemctl enable --now power-profiles-daemon.service 2>/dev/null || true
if [[ $(getent passwd "${USER:-$(id -un)}" | cut -d: -f7) != */zsh ]] && command -v zsh >/dev/null; then
    say "making zsh your shell"
    chsh -s "$(command -v zsh)" || warn "chsh failed; run: chsh -s $(command -v zsh)"
fi
# the microphone, cleaned (ultra-mic): load it and make it the default
if systemctl --user is-active --quiet pipewire; then
    say "the microphone"
    "$bin/ultra-mic" on || warn "could not set up the clear microphone; run ultra-mic"
fi
# text and code (md, py, cpp, json, ...) open in VS Code, when it is installed
for id in code visual-studio-code code-oss codium; do
    if [[ -f /usr/share/applications/$id.desktop ]]; then
        xdg-mime default "$id.desktop" text/plain text/markdown text/x-markdown text/x-python \
            text/x-python3 application/x-python-code text/x-c text/x-csrc text/x-chdr text/x-c++src \
            text/x-c++hdr text/x-c++ text/x-java text/x-rust text/x-go text/javascript \
            application/javascript text/x-typescript application/x-typescript application/json \
            application/x-yaml text/x-yaml application/yaml application/toml text/x-toml \
            application/xml text/xml text/x-shellscript application/x-shellscript text/x-script.python \
            text/x-lua text/x-cmake text/x-makefile text/x-log text/csv text/x-csv application/x-ini \
            text/x-ini text/x-diff text/x-patch application/x-desktop text/x-qml application/sql \
            text/x-sql || warn "could not make VS Code the text editor"
        break
    fi
done
# plain notes (txt, md) open in Text Editor, light and quick; code stays in VS Code
if [[ -f /usr/share/applications/org.gnome.TextEditor.desktop ]]; then
    xdg-mime default org.gnome.TextEditor.desktop text/plain text/markdown text/x-markdown \
        || warn "could not make Text Editor the editor for notes"
fi
# the standard folders (Documents, Templates, ...): Files' "New Document"
# offers what is in ~/Templates
command -v xdg-user-dirs-update >/dev/null && xdg-user-dirs-update || true
# pictures (screenshots included) open in gThumb: viewer and simple editor
for id in org.gnome.gThumb gthumb; do
    if [[ -f /usr/share/applications/$id.desktop ]]; then
        xdg-mime default "$id.desktop" image/png image/jpeg image/webp image/gif image/bmp \
            image/tiff image/avif image/heif image/svg+xml || warn "could not make gThumb the picture viewer"
        break
    fi
done
# ssh that survives a short Wi-Fi blip: keepalives every 15 s, giving up
# only after about two minutes of silence (added once, at the top of
# ~/.ssh/config, so they apply to every host)
mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
touch "$HOME/.ssh/config" && chmod 600 "$HOME/.ssh/config"
if ! grep -qiE '^\s*ServerAliveInterval' "$HOME/.ssh/config"; then
    say "ssh keepalive"
    printf 'ServerAliveInterval 15\nServerAliveCountMax 8\n\n%s' "$(cat "$HOME/.ssh/config")" >"$HOME/.ssh/config"
fi

# Wi-Fi power saving off, for good (a dozing card drops ssh and loses its
# way on the mesh): NetworkManager's own setting, the same for every kernel
nm_ps=/etc/NetworkManager/conf.d/archive-wifi-powersave.conf
if [[ -d /etc/NetworkManager ]] && ! grep -qs 'wifi.powersave = 2' "$nm_ps"; then
    say "Wi-Fi power saving: off"
    printf '# archive (setup.sh): Wi-Fi power saving off (2 = disable)\n[connection]\nwifi.powersave = 2\n' | sudo tee "$nm_ps" >/dev/null \
        && sudo systemctl reload NetworkManager 2>/dev/null || warn "could not switch Wi-Fi power saving off"
fi

# ultra-lan (the mesh Wi-Fi detour), where it is switched on: the new
# version installed and its watcher restarted, so an update takes effect
# (an older archive-lan handed over first, with its list of machines)
if [[ -f /etc/systemd/system/archive-lan.service ]]; then
    say "ultra-lan: taking over from archive-lan"
    was_on=0; systemctl is-enabled --quiet archive-lan.service 2>/dev/null && was_on=1
    sudo systemctl disable --now archive-lan.service >/dev/null 2>&1 || true
    sudo mkdir -p /etc/ultra
    [[ -f /etc/archive/lan-hosts && ! -f /etc/ultra/lan-hosts ]] && sudo mv /etc/archive/lan-hosts /etc/ultra/lan-hosts
    sudo rm -f /etc/systemd/system/archive-lan.service /usr/local/bin/archive-lan /etc/sysctl.d/99-archive-lan.conf
    sudo rmdir /etc/archive 2>/dev/null || true
    sudo systemctl daemon-reload
    (( was_on )) && { "$bin/ultra-lan" on >/dev/null || warn "could not switch ultra-lan on; run ultra-lan on"; }
elif systemctl is-enabled --quiet ultra-lan.service 2>/dev/null; then
    say "ultra-lan: updated"
    "$bin/ultra-lan" on >/dev/null || warn "could not update ultra-lan; run ultra-lan on"
fi

# stable GPU names for Hyprland (/dev/dri/amd-igpu, /dev/dri/nvidia-dgpu)
gpu_names() {
    local amd nv rules=""
    amd=$(lspci -d ::03xx | grep -i 'AMD' | head -n1 | cut -d' ' -f1 || true)
    nv=$(lspci -d ::03xx | grep -i 'NVIDIA' | head -n1 | cut -d' ' -f1 || true)
    [[ -n $amd ]] && rules+="KERNEL==\"card*\", KERNELS==\"0000:$amd\", SUBSYSTEM==\"drm\", SUBSYSTEMS==\"pci\", SYMLINK+=\"dri/amd-igpu\""$'\n'
    [[ -n $nv ]] && rules+="KERNEL==\"card*\", KERNELS==\"0000:$nv\", SUBSYSTEM==\"drm\", SUBSYSTEMS==\"pci\", SYMLINK+=\"dri/nvidia-dgpu\""$'\n'
    [[ -n $rules ]] || { warn "no AMD / NVIDIA display controller found; skipped"; return 0; }
    # (unchanged: left alone, so nothing is re-announced for no reason)
    if [[ $(cat /etc/udev/rules.d/90-archive-gpu-names.rules 2>/dev/null) != "${rules%$'\n'}" ]]; then
        printf '%s' "$rules" | sudo tee /etc/udev/rules.d/90-archive-gpu-names.rules >/dev/null
        # no `udevadm trigger` here: re-announcing the GPUs to a running
        # Hyprland can take it down. The names appear at the next boot.
        sudo udevadm control --reload
        note "the names appear after the next reboot"
    fi
}
# ------------------------------------------------------------------ 4. Zephyrus G14
model=$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)
if [[ $model == *Zephyrus*G14* || $model == *GA403* ]]; then
    say "Zephyrus G14 ($model): stable GPU names"
    gpu_names || warn "G14 step failed; see docs/zephyrus-g14.md"
    # the NVIDIA driver, built for the kernels you have (if it is not running)
    if lspci -d 10de: 2>/dev/null | grep -qiE 'vga|3d' && ! lsmod | grep -q '^nvidia '; then
        say "Zephyrus G14: the NVIDIA driver (Hybrid mode)"
        "$bin/ultra-rog" gpu || warn "the NVIDIA step failed; see docs/zephyrus-g14.md"
    fi
    # GPU switching is asusd's own now: the retired supergfxctl, left
    # running, keeps ROG Control's GPU page from working
    if pacman -Qq supergfxctl >/dev/null 2>&1; then
        say "Zephyrus G14: GPU switching through asusd (supergfxctl retired)"
        "$bin/ultra-rog" switch || warn "could not hand GPU switching to asusd; run ultra-rog switch"
    fi
    # Quiet on battery, Balanced plugged in; no ROG Control notifications
    "$bin/ultra-rog" power || warn "could not set the power profiles; run ultra-rog power"
    # waking without the black text screen: the NVIDIA driver suspends itself when it can
    if lsmod | grep -q '^nvidia '; then
        "$bin/ultra-rog" sleep || warn "could not change how the NVIDIA driver sleeps; run ultra-rog sleep"
    fi
    note "fan curves, battery limit and GPU modes: see docs/zephyrus-g14.md (asusctl, ROG Control)"
fi

# ------------------------------------------------------------------ restore points
# Timeshift: one before every system update and one a day, so an update
# that breaks something can be undone (ultra-snapshot); kept current, unless
# you turned it off (ultra-snapshot off)
if [[ -f /etc/pacman.d/hooks/00-archive-snapshot.hook || -f /usr/local/bin/archive-snapshot ]]; then
    # (the older archive-snapshot: its hook and timer make way for the new ones)
    sudo systemctl disable --now archive-snapshot.timer >/dev/null 2>&1 || true
    sudo rm -f /etc/pacman.d/hooks/00-archive-snapshot.hook /etc/systemd/system/archive-snapshot.service \
        /etc/systemd/system/archive-snapshot.timer /usr/local/bin/archive-snapshot
    sudo systemctl daemon-reload
fi
if [[ ! -f $state/ultra/snapshots-off ]] \
    && { [[ ! -f /etc/pacman.d/hooks/00-ultra-snapshot.hook ]] \
         || ! cmp -s "$bin/ultra-snapshot" /usr/local/bin/ultra-snapshot; }; then
    say "restore points: one before each update, and one a day"
    "$bin/ultra-snapshot" on || warn "restore points were not set up; run ultra-snapshot on"
fi

# ------------------------------------------------------------------ a quiet start, and the power button
# your theme's own page while it starts and shuts down, not scrolling text;
# a press of the power button opens the power menu, holding it shuts down
say "a quiet start: your theme's page instead of the start-up text"
"$bin/ultra-boot" quiet --auto || warn "the quiet start was not set up; run ultra-boot quiet"
"$bin/ultra-boot" power || warn "the power button was not set up; run ultra-boot power"

# ------------------------------------------------------------------ memory
# compressed swap in memory (zram): when memory runs short, pages are
# squeezed in RAM instead of the laptop slowing to a crawl
say "memory: compressed swap in RAM (zram)"
"$bin/ultra-memory" on || warn "zram was not set up; run ultra-memory on"

# ------------------------------------------------------------------ small tunings
# a quicker start and stop, a little less power at rest, a trimmed disk
# (ultra-tune); kept current, unless you turned it off (ultra-tune off)
if [[ ! -f $state/ultra/tune-off ]]; then
    say "small tunings: a quicker start and stop, less power at rest (ultra-tune)"
    "$bin/ultra-tune" on || warn "the tunings were not set; run ultra-tune on"
fi

# ------------------------------------------------------------------ 5. each theme's own
# Icons and the title-bar plugin are made per theme, from its own folder, so
# a theme you switch to later is ready at its first login. A wallpaper of
# your own (ultra-wallpaper) is kept per theme too, and made again here.
for box in "$here"/themes/*/; do
    box=${box%/}; id=${box##*/}
    [[ -d $box/home ]] || continue
    say "theme: $id"
    tbin="$box/home/.local/bin"
    if [[ -x $tbin/ultra-icons ]]; then
        "$tbin/ultra-icons" ensure || warn "$id: could not make the icons; run ultra-icons"
    fi
    if compgen -G "$config/ultra/$id/wallpaper.*" >/dev/null && [[ -f $box/tools/import_wallpaper.py ]]; then
        if python3 "$box/tools/import_wallpaper.py" --is-theme-copy 2>/dev/null; then
            # only an older copy of the theme's own sheet: the theme's new one shows instead
            rm -f "$config/ultra/$id"/wallpaper.*
            [[ $id == "$theme" ]] && ultra_theme apply "$id" --force >/dev/null
        else
            note "your wallpaper"
            python3 "$box/tools/import_wallpaper.py" >/dev/null || warn "$id: could not rebuild your wallpaper; run ultra-wallpaper"
        fi
    fi
    if [[ -x $tbin/ultra-bars ]]; then
        note "title bars and paper edges for your Hyprland (a minute or two)"
        "$tbin/ultra-bars" update >/dev/null 2>&1 \
            || { warn "$id: the plugin did not build (log: ~/.cache/ultra/$id/archivebars/build.log)"
                 note "everything else works; windows get plain straight edges until it builds (it retries at every login)"; }
    fi
done
# the theme in place: GTK, Qt and the terminal matched to it
[[ -x $bin/ultra-mode ]] && { "$bin/ultra-mode" start || true; }

# ------------------------------------------------------------------ 6. login screen
greeter() {
    say "greetd + tuigreet (a typed login that starts Hyprland)"
    sudo tee /etc/greetd/config.toml >/dev/null <<'EOF'
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --time-format '%a %d %b  %H:%M' --remember --asterisks --asterisks-char x --greeting 'Signature required.' --cmd start-hyprland"
user = "greeter"
EOF
    sudo systemctl enable greetd.service
    warn "greetd takes over tty1 from the next boot; disable any other display manager first"
}
active_dm=$(systemctl list-unit-files --state=enabled 2>/dev/null | grep -oE '^(gdm|sddm|lightdm|ly|greetd)\.service' | head -n1 || true)
if [[ $active_dm == greetd.service ]]; then
    note "greetd is already your login screen"
elif [[ -n $active_dm ]]; then
    note "keeping your login screen ($active_dm); pick Hyprland there"
elif ask "Start Hyprland at boot from a typed login screen (greetd)?"; then
    greeter || warn "greeter step failed"
fi

say "done"
cat <<'EOF'
   Now reboot (sudo reboot). Until then this session keeps its old look.

   The commands are called ultra-... now (ultra-update, ultra-ros,
   ultra-rog, ultra-lan ...); the old archive-... names are gone.

   Themes: Super + Space, type "Themes" (or: ultra-theme set <id>), then
   log out and in. Only the chosen theme is ever in your home.

   Super + Space  launcher          Super + N   day / night
   Super + Return terminal          Super + I   quick settings
   Everything else: ~/ultra/GUIDE.md
EOF
