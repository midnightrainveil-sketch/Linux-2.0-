# Ultra: themed desktops for Arch + Hyprland

A machine setup (`core/`) and a set of desktop themes (`themes/`), each theme
a self-contained box; only the chosen one is ever linked into the home
folder. Two ship: **Archive** (a botanical herbarium, below) and
**Compartment 19** (a 1930s Vienna to Venice night train).

The Archive: the desktop as a sheet in a botanical archive. Windows are typed index cards
lying on the sheet, the wallpaper is the pressed specimen, and the bar is the
printed footer of the page. Grey paper and graphite by day; cyanotype blue at
night.

Built for the **ASUS ROG Zephyrus G14 (2024)** on Arch Linux, with
**Hyprland 0.55+** (Lua config) and **Quickshell 0.3+**. Everything except the
machine file is portable.

![Day](docs/img/preview-day.jpg)

<sub>Rendered from the shell's own QML. Window shadows and the real terminal
are left out of this offscreen preview.</sub>

## Start here

On an Arch Linux that already runs Hyprland, one command installs the whole
theme:

```sh
git clone https://github.com/midnightrainveil-sketch/Linux-2.0-.git ~/ultra
~/ultra/setup.sh
```

(or unpack it anywhere and run `./setup.sh` in it; it copies itself to
`~/ultra`). It installs the packages, links the
configuration (your old files go to `~/.ultra-backup/`), names the G14's
GPUs if it finds a G14, builds the title-bar and paper-edge plugin, and offers
a typed login screen. Then reboot.

To update later, run `ultra-update` in a terminal: it downloads the latest
version and runs the same setup (then reboot).

**→ [GUIDE.md](GUIDE.md)** walks through the same steps by hand, from a fresh
Arch install, with a check after each one.

## What's inside

| | |
| --- | --- |
| **Plate** (wallpaper) | The *Geranium pratense* sheet, whole, with its typed labels, stamp and tape; at night the same sheet printed as a cyanotype. Plates without text also work: then the shell types the labels itself. |
| **The desk** | At login: the three record cards on the right and a live terminal on the left, as in the reference. Drag them anywhere, right-click a card to put it away, close the terminal; the card button in the bar (or `Super + D`) lays the desk out again. |
| **Record cards** | Time Record (clock, date, week, coordinates), Meteorological Observation (Open-Meteo, no key), Audio Archive (any MPRIS player). Every `No.` is real data. |
| **Footer bar** | Sprig (launcher), typed workspaces with a blue underline, `/ home / atlas /` breadcrumb, sketched status marks, date. |
| **Popups** | Card Catalogue (launcher), Ledger (calendar), Instrument card (Wi-Fi, Bluetooth, battery, power profile, day/night, grain, volume and light rulers), Disposition (power menu). |
| **Correspondence** | The notification daemon: cards with a RECEIVED stamp; critical ones stay, with a madder URGENT stamp. |
| **Reading Room** | The lock screen. Signature field; REJECTED or ADMITTED stamps. |
| **Windows** | Paper cards with torn edges (drawn by the archivebars plugin from repeating tiles, any size), soft shadows, typed title bars with three ticket-stub buttons and a ruled line, damped motion. |
| **Night** | At sunset the whole sheet crossfades over 2 s to cyanotype, and GTK, Qt and foot follow. |
| **Extras** | Paper grain per window (terminals and system tools; a title-bar toggle), colour profiles (ICC), foley sound theme hooks, screenshot filing with a stamp, plate importer. |

![Cards](docs/img/preview-cards.jpg)

## Repository layout

```
setup.sh                    installs everything (run again to update)
GUIDE.md                    the install guide, phase by phase
core/                       the machine, shared by every theme
  home/.config/hypr/        hyprland.lua (the selector), ultra/machine.lua
  home/.config/zsh, pipewire
  home/.local/bin/          ultra-theme, ultra-update, ultra-rog, ultra-lan, ultra-ros,
                            ultra-refresh, ultra-snapshot, ultra-brightness, ultra-mic, ...
  packages/                 pacman package lists
  system/plymouth/          the start-up page
themes/                     one folder per theme (see themes/README.md)
  archive/                  the herbarium
  night-service/            Compartment 19
    theme.json, preview-*.jpg
    home/                   linked into $HOME while the theme is on:
      .config/hypr/theme.lua + theme/*.lua, quickshell/, foot, gtk, qt6ct ...
      .local/bin/           ultra-mode, ultra-desk, ultra-bars, ultra-icons, ...
      .local/share/         fonts, cursors, sounds, plates, the title-bar plugin
    tools/, art/            importers and source artwork
docs/                       G14 notes, customising, design map, troubleshooting
```

## Docs

- [GUIDE.md](GUIDE.md): installation, phase by phase
- [docs/zephyrus-g14.md](docs/zephyrus-g14.md): the laptop side: asusctl, GPU modes, NVIDIA, battery
- [docs/customise.md](docs/customise.md): settings, colours, plates, keybinds
- [docs/design-map.md](docs/design-map.md): every rule of the design spec, and where it lives
- [docs/troubleshooting.md](docs/troubleshooting.md)
- [docs/assets-wanted.md](docs/assets-wanted.md): the artwork sources in `art/` and how to replace them

## Credits

- Typefaces: [Courier Prime](https://github.com/quoteunquoteapps/CourierPrime)
  and [Pinyon Script](https://fonts.google.com/specimen/Pinyon+Script), both
  under the SIL Open Font License (licences included next to the fonts);
  [IBM Plex](https://github.com/IBM/plex) from the Arch repos.
- [Hyprland](https://hypr.land), [hyprland-plugins](https://github.com/hyprwm/hyprland-plugins)
  (hyprbars), [Quickshell](https://quickshell.org), [Open-Meteo](https://open-meteo.com).
