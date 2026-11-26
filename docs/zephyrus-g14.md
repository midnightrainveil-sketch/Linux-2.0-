# Zephyrus G14 (2024, GA403) on Arch

A checklist for the laptop side, so the desktop runs smoothly. Skip anything
you already did. The asus-linux project keeps the reference guide at
<https://asus-linux.org/guides/arch-guide/>. If anything here differs from
it, follow theirs: it is updated with each kernel.

The hardware: AMD Ryzen 9 8945HS with Radeon 780M (iGPU), an NVIDIA RTX
4060 or 4070 (dGPU) behind a MUX switch, and a 14″ 2880×1800 120 Hz OLED.

## 1. The asus-linux repository

It provides `asusctl`, `rog-control-center` and, if you want
it, the `linux-g14` kernel.

```sh
sudo pacman-key --recv-keys 8F654886F17D497FEFE3DB448B15A6B0E9A3FA35
sudo pacman-key --finger 8F654886F17D497FEFE3DB448B15A6B0E9A3FA35
sudo pacman-key --lsign-key 8F654886F17D497FEFE3DB448B15A6B0E9A3FA35
```

Check the key on the asus-linux guide before you trust it, then add the
repository to the end of `/etc/pacman.conf`:

```ini
[g14]
Server = https://arch.asus-linux.org
```

```sh
sudo pacman -Syu
sudo pacman -S --needed asusctl power-profiles-daemon switcheroo-control rog-control-center
sudo systemctl enable --now power-profiles-daemon switcheroo-control
```

The default `linux` kernel supports the 2024 G14 well. `linux-g14` carries
ASUS patches ahead of mainline. Install it only if something specific
(keyboard LEDs, a fan curve) is missing, and keep `linux` as a fallback entry
in GRUB.

## 2. NVIDIA driver

The RTX 40 series uses the open kernel modules:

```sh
sudo pacman -S --needed nvidia-open-dkms nvidia-utils lib32-nvidia-utils linux-headers
# (use linux-g14-headers as well if you run linux-g14)
```

So that the dGPU survives suspend:

```sh
echo 'options nvidia NVreg_PreserveVideoMemoryAllocations=1' | sudo tee /etc/modprobe.d/nvidia-power.conf
sudo systemctl enable nvidia-suspend nvidia-resume nvidia-hibernate
```

Those services switch to a text console on the way to sleep and back on
waking (a black screen with a blinking cursor, and a few seconds before the
lock screen). With driver 595 or newer (open modules) the driver can suspend
itself instead: `ultra-rog sleep` sets
`NVreg_UseKernelSuspendNotifiers=1` and switches the services off (the setup
does it when the driver is new enough). Reboot afterwards.

Then rebuild the initramfs and reboot:

```sh
sudo mkinitcpio -P
sudo reboot
```

Check with `nvidia-smi`. It should list the GPU, and in Hybrid mode it may
show the card asleep.

## 3. GPU mode

Since asusctl 6.3.9, asusd switches the GPU itself: use the **GPU page in
ROG Control** (the Machine button in Instruments). `supergfxctl` is retired
upstream, and a `supergfxd` still running keeps asusd from switching;
`ultra-rog switch` removes it. The switching goes through the kernel's
`asus-armoury` driver, in **Linux 6.19 and newer**: on `linux-lts` 6.18 the
GPU page has nothing to switch, so start the regular `linux` kernel.
`ultra-rog status` shows what the kernel offers.

| Mode | When |
| --- | --- |
| **Integrated** (every boot) | longest battery; the dGPU is switched off |
| Hybrid | when you choose it; the iGPU drives the screen, the dGPU wakes for games and CUDA and sleeps (no power) otherwise |
| Ultimate (MUX dGPU) | games only; the dGPU drives the panel directly (needs a reboot) |

Every boot starts in **Integrated**. The firmware wakes the laptop in Hybrid
on most boots, so a root service, `ultra-gpu-boot` (installed by `setup.sh`),
switches it before the login screen. It unloads the NVIDIA driver, takes the
dGPU off the bus, and sets `dgpu_disable` through asusd. If anything holds the
dGPU, or the driver will not unload, it leaves Hybrid alone. Hybrid is then
only what you choose (ROG Control's GPU page, `asusctl armoury set
dgpu_disable 0`, the control deck) and lasts until the next boot. To start
every boot in Hybrid instead: `ultra-gpu default hybrid`
(`ultra-gpu default integrated` to go back). What it did at the last boot:
`journalctl -b -u ultra-gpu-boot`.

A mode change asks you to log out. In MUX dGPU mode the internal panel is
often called `eDP-2`. `machine.lua` covers both names.

To run one program on the dGPU in Hybrid mode, use
`prime-run <program>` (from `nvidia-prime`), or in Steam set the launch
option `prime-run %command%`.

## HDR

The G14's OLED is an HDR panel, and Hyprland can drive it in HDR. It is off
by default, because Hyprland still calls its HDR experimental:

```bash
ultra-hdr on        # 10-bit colour, HDR's gamut and PQ curve
ultra-hdr off       # plain SDR again (and your colour profile)
ultra-hdr status    # the choice, and the panel's pixel format now
```

It takes effect at once and holds after a reboot. Everything that is not
HDR (the desktop, most apps) is mapped into it; if that looks too dim or
too pale, set `"hdrSdrBrightness"` (about 1.0 to 1.5) and
`"hdrSdrSaturation"` in `~/.config/ultra/settings.json`. A colour profile
(`ultra-icc`) is set aside while HDR is on. What shows real HDR: mpv
(`vo=gpu-next`), games through Proton with `PROTON_ENABLE_WAYLAND=1
PROTON_ENABLE_HDR=1` (or gamescope with `--hdr-enabled`), and browsers as
far as their own HDR support goes. Known rough edges in Hyprland: on some
laptops the brightness keys stop changing the panel while HDR is on, and
some setups flicker; `ultra-hdr off` puts it back as it was.

## 4. Stable GPU names for Hyprland

`./setup.sh` writes a udev rule that creates `/dev/dri/amd-igpu` and
`/dev/dri/nvidia-dgpu`. Hyprland is then told to render on the iGPU first
(`AQ_DRM_DEVICES` in `~/.config/hypr/ultra/machine.lua`). The dGPU stays
listed so a monitor on the HDMI port (wired to the NVIDIA card on this model)
still works. The names appear at the next boot (the rule is not applied to
a running session: re-announcing the GPUs to a live Hyprland can crash it).

## 5. Display

`machine.lua` sets the panel to `2880x1800@120` at scale `1.5`. That's
1920×1200 logical pixels: the mockup's 1920 width, plus the extra 16:10
height, which the record column uses as breathing room.

- For larger text, use scale `1.6` (1800×1125). The layout adapts.
- OLED care: the bar and the plate never move. Raise the idle timers in
  `~/.config/hypr/hypridle.conf` if you leave the laptop on unattended, and
  consider *Panel overdrive off* and *Pixel refresh* in rog-control-center.

## 6. Battery

- A charge limit protects the battery. Set it in **ROG Control Center →
  Battery** (or `asusctl -c 80` with older asusctl). 80 % is a good everyday
  value.
- The fan key (`Fn + F5`) cycles Quiet → Balanced → Performance through
  `power-profiles-daemon`. asusctl follows it, and the Instruments card
  shows it.
- The profile follows the charger: Quiet on battery, Balanced plugged in
  (`ultra-rog power`, run by `setup.sh`; asusd does the switching).
  `ultra-rog calm` stops the switching instead. Both stop ROG Control's
  notifications and its background copy.
- Graphics: Integrated at every boot (`ultra-gpu-boot`, see above); Hybrid
  when you switch to it, until the next boot. In Hybrid the screen runs on
  the iGPU (the MUX stays there) and the dGPU wakes for whatever asks for it
  (`prime-run`, games), then powers off again. `ultra-rog gpu` installs the
  driver with headers for every kernel you have (linux-lts needs
  linux-lts-headers), the dGPU power settings and Hybrid mode; `setup.sh`
  runs it when the driver is not loaded. `ultra-rog status` shows the
  driver, the dGPU's state and the profile.
- hypridle dims at 2.5 min, locks at 5, turns the screen off at 5.5, and
  suspends after 20 min on battery.

## 7. Keyboard

- Keyboard backlight: `Fn + F2` / `Fn + F3` (`brightnessctl -d asus::kbd_backlight`).
- If a G14 key does nothing, run `wev` (from the `wev` package), press the key,
  and put the `sym` it prints into `~/.config/hypr/theme/binds.lua`.
- The AniMe Matrix on the lid (some G14 models) is controlled with `asusctl anime`.
  To keep the desk quiet, turn it off.

## 8. Audio

The 2024 G14 speakers use Cirrus Logic amplifiers, which need recent firmware:

```sh
sudo pacman -S --needed sof-firmware alsa-ucm-conf linux-firmware
```

If the headphones work but the speakers are silent, update everything
(`sudo pacman -Syu`) and reboot. The support lands with the kernel and the
firmware.

## 9. Windows side

- Make Windows keep the clock in UTC (see Phase 0 of the guide).
- Turn off Fast startup.
- If BitLocker is on, keep the recovery key handy: changing boot settings can
  trigger it.
