# Customising the archive

## settings.json

`~/.config/archive/settings.json` is read by the shell (it applies changes as
soon as you save), by Hyprland (on reload) and by `archive-mode`.

| Key | Default | Meaning |
| --- | --- | --- |
| `archive.name` | `ROYAL BOTANIC ARCHIVE` | Title of the Time Record and Reading Room cards |
| `archive.stamp` | `REG. BOT. ARCHIVUM` | Text around the oval stamp |
| `location.name`, `.country` | Singapore | Typed in the Meteorological card's footer |
| `location.latitude`, `.longitude` | 1.3521, 103.8198 | Weather, and the Time Record's coordinates |
| `dayStart`, `nightStart` | `07:00`, `19:10` | When the sheet turns to paper and to cyanotype |
| `bar.minWorkspaces` | `4` | Workspaces always typed in the bar (more appear when used, up to 9) |
| `records.time`, `.weather`, `.audio` | `true` | Which record cards lie on the sheet |
| `plate` | `""` | Pin one plate by id; empty means a new plate each day |
| `deskTerminal` | `true` | Open the fastfetch terminal card at login |
| `reducedMotion` | `false` | Every transition becomes a 100 ms fade (shell and Hyprland) |
| `paperEdges` | `true` | Torn paper edges around windows (needs the archivebars plugin); `false` gives straight rims |
| `sounds` | `true` | Play the archive sounds |
| `doNotDisturb` | `false` | Only critical notifications show (all are still kept) |

After changing `reducedMotion`, `paperEdges` or `deskTerminal`, run `hyprctl reload`.

### The torn window edge

Its shape is set in `~/.config/hypr/archive/look.lua` (the `deckle_*` lines):

| Option | Default | Effect |
| --- | --- | --- |
| `deckle_margin` | `6` | How far the card's edge sits outside the window (raise `gaps_in` with it) |
| `deckle_amplitude` | `1.2` | How far the torn line wanders, in px. `0` gives a clean cut |
| `deckle_rim_width` | `1.3` | Weight of the outline |
| `deckle_period` | `160` | Length of one repeating strip |
| `deckle_shadow_blur`, `_x`, `_y` | `4.5`, `1.5`, `3` | The card's shadow (down and to the right) |
| `deckle_chips` | `1` | How often edges are chipped, torn and wrinkled; `0` gives a clean cut, `2` a well-handled card |
| `deckle_creases` | `1` | How often a corner is creased; `0` for none |
| `deckle_tone`, `deckle_tone_depth` | `edge_tone`, `18` | The aged edge: its colour (alpha is its strength; alpha `00` turns it off) and how far in it reaches |

The colours come from `palette.lua` (`edge_top`, `rim_bottom`, `bevel`,
`edge_shadow`, `edge_tone`, and `_flat` versions for unfocused windows). To preview a
change without logging out, build the preview tool (see the top of
`tools/deckle-preview.cpp`) and render a card to a PNG.

## Colours

The palette is defined in three places. Keep them in sync:

1. `~/.config/quickshell/theme/Theme.qml`: the shell, day (`day`) and night (`nite`).
2. `~/.config/hypr/archive/palette.lua`: borders, shadows and title bars.
3. `tools/gen_themes.py` (run it again after editing): GTK and Qt.

The terminal palette is in `~/.config/foot/foot.ini`: `[colors-light]` by day
and `[colors-dark]` by night.

## Fonts

Courier Prime is the archive's typewriter: the shell, the window titles and
the terminal (foot, 14.5 pt, with IBM Plex Mono behind it for box-drawing and
symbols). Pinyon Script is used once per screen for Latin names, and IBM Plex
Sans is for apps (IBM Plex Mono for code in them). To give the terminal a
plainer face for long sessions, change the `font=` lines in
`~/.config/foot/foot.ini` to IBM Plex Mono. Sizes are set in `Theme.qml` (`sizeClock`, `sizeTitle`...).
Fontconfig defaults are in `~/.config/fontconfig/fonts.conf`.

## Layout

- Record column width: `Theme.recordWidth` (480 px, a quarter of 1920).
- Margins and gaps: `Theme.margin`, `Theme.cardGap`, `Theme.cardPad`.
- Wallpaper labels: the positions in `modules/background/Plate.qml` are
  fractions of the screen, taken from the mockup.
- Where the plant sits: the `box` in each plate's `meta.json` (left, top,
  right, bottom as fractions of the screen).

## Window behaviour

- Keybinds: `~/.config/hypr/archive/binds.lua`. The terminal, file manager and
  browser are set at the top.
- Which windows float as small centred cards: `small_tools` in `archive/rules.lua`.
- Your own Hyprland additions: create `~/.config/hypr/user.lua`. It's loaded
  last, and git ignores it.

## Idle and lock

`~/.config/hypr/hypridle.conf`: dim, keyboard light off, lock, screen off,
suspend.

## Day / night by hand

```sh
archive-mode night     # until the next sunrise or sunset
archive-mode day
archive-mode toggle
archive-mode auto      # back to the clock right away
```

## Plates

```sh
archive-plate list
archive-plate import IMAGE --latin "Genus species" [--authority --family --common --loc --hab --leg --det --dat]
archive-plate pin ID
archive-plate daily
archive-plate remove ID
```

A plate's `meta.json` holds its names, the specimen label, the `tapes`
(position, width and angle as fractions of the plate box), the scale `marks`
("1:1", "2:1") and the `box`.

## Regenerating assets

```sh
python3 tools/import_art.py        # twig, icons, weather sketches from art/
python3 tools/import_wallpaper.py  # the starter plate from art/wallpaper.webp
python3 tools/gen_assets.py        # paper grain, card texture, fallback SVG icons
python3 tools/gen_themes.py        # GTK and Qt colour files
```
