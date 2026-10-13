# Troubleshooting

## The shell (wallpaper, bar, cards) does not appear

Run it in a terminal to see its errors:

```sh
pkill -x qs; qs
```

- `module "Quickshell.Networking" is not installed` (or similar): Quickshell
  is older than 0.3. Run `sudo pacman -Syu`, and check with `qs --version`.
- `module "Qt5Compat.GraphicalEffects" is not installed`:
  `sudo pacman -S qt6-5compat`.
- Icons missing: `sudo pacman -S qt6-svg`.
- To start it in the background again: `qs -d` (Hyprland also starts it at login).

## Hyprland shows a red error bar

The bar names the file and line. To read it again later, run
`hyprctl configerrors`. If you edited `user.lua`, check it first. The most
common cause is a plugin option set before the plugin loaded, which is why
`look.lua` checks `hl.plugin.hyprbars ~= nil`.

## No title bars on windows

```sh
hyprpm list            # is hyprbars enabled?
hyprpm update          # after every Hyprland update
hyprpm reload -n
```

If hyprpm fails to build, check that `base-devel cmake meson cpio` are installed.

## Black screen or Hyprland won't start on the G14

- Switch to tty2 with `Ctrl + Alt + F2`, log in, and read the log:
  `cat $XDG_RUNTIME_DIR/hypr/*/hyprland.log | tail -50`.
- Check the GPU names: `ls -l /dev/dri/amd-igpu /dev/dri/nvidia-dgpu`.
  If they are missing, run `./install.sh --g14` and reboot.
- If you switched to *AsusMuxDgpu* mode, the iGPU no longer drives the
  panel. Go back to Hybrid (`supergfxctl -m Hybrid`) or remove `amd-igpu` from
  `machine.lua`.

## The lock screen crashed (solid colour, cannot unlock)

That's Wayland keeping you safe: the lock stays even if the shell dies. From
another TTY (`Ctrl + Alt + F2`):

```sh
hyprctl --instance 0 dispatch 'hl.dsp.exec_cmd("qs")'
hyprctl --instance 0 dispatch 'hl.dsp.exec_cmd("qs ipc call lock lock")'
```

Go back with `Ctrl + Alt + F1` and sign in. `allow_session_lock_restore` is
on in `look.lua` for exactly this.

## Unlock always says REJECTED

The lock screen checks your password with `pam_unix` only
(`~/.config/quickshell/pam/password.conf`). The keyboard layout on the lock
screen is the session's (`kb_layout` in `machine.lua`).

## Weather says "Awaiting reading."

- Check the coordinates in `~/.config/archive/settings.json`.
- Check the network: `curl -s "https://api.open-meteo.com/v1/forecast?latitude=1.35&longitude=103.82&current=temperature_2m"`.
- The shell tries again every minute after a failure, and every 15 minutes
  once it has a reading.

## Day / night does not switch

```sh
archive-mode status
systemctl --user status archive-mode.timer
cat ~/.local/state/archive/mode-hold 2>/dev/null && date +%s   # a manual choice is being held
archive-mode auto
```

## foot: `[colors-dark]: invalid section name`

Your foot is older than 1.26. Update it, or rename `[colors-light]` to
`[colors2]` and `[colors-dark]` to `[colors]` in `~/.config/foot/foot.ini`.
Then swap the `USR1` and `USR2` signals in `archive-mode`.

## Fonts look wrong (not typewriter)

```sh
fc-list | grep -i -E "courier prime|pinyon|plex"
fc-cache -f
```

Courier Prime and Pinyon Script are in `~/.local/share/fonts/archive/`. IBM
Plex comes from the `ttf-ibm-plex` package.

## Volume or brightness keys show nothing

- Volume: `wpctl status` should list a default sink. The shell shows the
  reading when PipeWire reports a change.
- Brightness: `brightnessctl -l` should list `amdgpu_bl*` (or `nvidia_wmi_ec_backlight`
  in MUX mode).

## Notifications from apps still use another daemon

Only one notification daemon can run at a time. Remove `mako` and `dunst`,
or stop them: `pkill mako; pkill dunst`.

## Starting over

Your old files are in `~/.archive-backup/<date>/`. To remove the links, run
`find ~ -lname "$HOME/archive/dotfiles/*" -delete`, then copy back what you need.
