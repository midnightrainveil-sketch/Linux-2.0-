# Zephyrus G14 (2024, GA403) on Arch

A checklist for the laptop side, so the desktop runs smoothly. Skip anything
you already did. The asus-linux project keeps the reference guide at
<https://asus-linux.org/guides/arch-guide/>. If anything here differs from
it, follow theirs: it is updated with each kernel.

The hardware: AMD Ryzen 9 8945HS with Radeon 780M (iGPU), an NVIDIA RTX
4060 or 4070 (dGPU) behind a MUX switch, and a 14″ 2880×1800 120 Hz OLED.

## 1. The asus-linux repository

It provides `asusctl`, `supergfxctl`, `rog-control-center` and, if you want
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
sudo pacman -S --needed asusctl power-profiles-daemon supergfxctl switcheroo-control rog-control-center
sudo systemctl enable --now power-profiles-daemon supergfxd switcheroo-control
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

Then rebuild the initramfs and reboot:

```sh
sudo mkinitcpio -P
sudo reboot
```

Check with `nvidia-smi`. It should list the GPU, and in Hybrid mode it may
show the card asleep.

## 3. GPU mode

| Mode | When | Command |
| --- | --- | --- |
| **Hybrid** (recommended) | everyday use; the iGPU drives the screen, the dGPU wakes for games and CUDA | `supergfxctl -m Hybrid` |
| Integrated | longest battery; the dGPU is switched off | `supergfxctl -m Integrated` |
| AsusMuxDgpu | games only; the dGPU drives the panel directly (needs a reboot) | `supergfxctl -m AsusMuxDgpu` |

A mode change asks you to log out. In MUX dGPU mode the internal panel is
often called `eDP-2`. `machine.lua` covers both names.

To run one program on the dGPU in Hybrid mode, use
`prime-run <program>` (from `nvidia-prime`), or in Steam set the launch
option `prime-run %command%`.

## 4. Stable GPU names for Hyprland

`./install.sh --g14` writes a udev rule that creates `/dev/dri/amd-igpu` and
`/dev/dri/nvidia-dgpu`. Hyprland is then told to render on the iGPU first
(`AQ_DRM_DEVICES` in `~/.config/hypr/archive/machine.lua`). The dGPU stays
listed so a monitor on the HDMI port (wired to the NVIDIA card on this model)
still works.

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
- hypridle dims at 2.5 min, locks at 5, turns the screen off at 5.5, and
  suspends after 20 min on battery.

## 7. Keyboard

- Keyboard backlight: `Fn + F2` / `Fn + F3` (`brightnessctl -d asus::kbd_backlight`).
- If a G14 key does nothing, run `wev` (from the `wev` package), press the key,
  and put the `sym` it prints into `~/.config/hypr/archive/binds.lua`.
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
