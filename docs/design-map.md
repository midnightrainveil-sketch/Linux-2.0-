# Design map: spec → implementation

Where each rule of the design language lives, and where the implementation
has to differ from the spec, with the reason.

Paths are relative to `dotfiles/`. `qs/` means `.config/quickshell/`.

## 1. Principles

| Rule | How |
| --- | --- |
| Everything is a record | Every surface is an `IndexCard` (`qs/components/IndexCard.qml`) with a `HeaderBand` title, a `No.` and ruled `DataRow`s |
| Paper, ink, nothing else | No blur anywhere (`decoration.blur.enabled = false`), no gradients, no rounding. Depth is the `Paper` shadow only |
| Imperfect on purpose | Cut card edges, wobbling rules, ink bleed and uneven stamps are drawn with seeded randomness (`qs/components/Rand.js`), so each card always keeps the same imperfections |
| Blue means alive | `Theme.accent` is used only for the active workspace, progress, stamps, the selected row, toggles and the caret |
| The specimen owns the centre | Records sit right, the desk terminal left. The plate box is the centre third |
| Quiet by default | Three cards, slow and damped motion, sounds only for real events |

## 2. Colour

| Spec | File |
| --- | --- |
| Tokens, day and night | `qs/theme/Theme.qml`, `.config/hypr/archive/palette.lua`, `tools/gen_themes.py` |
| Terminal ANSI 16 | `.config/foot/foot.ini` (`[colors-light]` is the spec table; `[colors-dark]` is a cyanotype adaptation) |
| Madder only when wrong | Low battery, critical notifications, REJECTED, unknown commands in zsh |

## 3. Typography

| Style | Where |
| --- | --- |
| Courier Prime: clock 64 bold, title 11 bold caps +12 %, data 12, label 11 | `Theme.size*`; `InkText` applies the tracking |
| IBM Plex Mono | foot, fastfetch, `fonts.conf` monospace |
| Pinyon Script | Latin name on the plate and on the lock screen only |
| IBM Plex Sans for apps | GTK `settings.ini`, qt6ct, `fonts.conf` |
| No "Herbarium" on screen | Labels say *Archive*, *Archivum*, *Flora*. Checked with `grep` |

**Different from the spec:** the plate's Latin name is 34 px, not 22. At
1920 px wide the mockup's script is visibly larger than the 22 px token, and
the plate is the one place that should match the mockup.

## 4. Texture

| Treatment | How |
| --- | --- |
| Paper grain 6–10 % (night 8–12 %) | `assets/grain-dark.png` and `grain-light.png`, 512 px seamless tiles from `tools/gen_assets.py`. `Theme.grainDark` / `grainLight` set the strength |
| Irregular cut edge, 1–2 px | `qs/components/Paper.qml` draws the card as a polygon with a seeded 1.4 px jag (see below) |
| Ruled lines 1.5 px, ±0.5 px drift | `qs/components/Rule.qml` |
| Ink bleed: 0.4 px ghost at 25 % | `qs/components/InkText.qml` |
| Stamps: uneven ink, ±8°, 75–85 % | `qs/components/Stamp.qml` (knock-out specks and scuffs) |
| Foxing: 3–6 spots, wallpaper only | `qs/modules/background/Plate.qml` |
| Optional global grain | `.config/hypr/shaders/grain.frag`, toggled by `archive-grain` / `Super + Shift + G` |

**Different from the spec:**

- The card edge is a Canvas polygon, not a 9-slice `BorderImage` mask. The
  polygon takes the current paper colour directly, so cards crossfade with
  day and night. A coloured 9-slice image would need a recolouring shader.
- The screen grain is static, not animated. A `time`-driven shader makes
  Hyprland redraw every frame (and turn damage tracking off), which is bad
  for a laptop battery. A static grain still reads as paper.

## 5. Layout

| Spec | How |
| --- | --- |
| Left desk ~35 %, centre ~35 %, right ~25 %, footer 40 px | Desk terminal rule (`archive/rules.lua`: 35.7 % × 43 % at the 32 px margin), plate box 0.375–0.665, `Theme.recordWidth` 480, `Theme.barHeight` 40 |
| 8 px grid; margins 32, gaps 24, padding 16, header 10/14, rows 30 | `Theme.qml` |
| Window gaps 8 between, 24 to the edge | `gaps_in = 4` (Hyprland doubles it between windows), `gaps_out = 24` |
| 16:10: extra height as breathing room | `Records.qml` spreads the spare height between the cards, never adding one |

## 6. Windows

| Spec | How |
| --- | --- |
| Focused: 2 px graphite border, 14 px shadow, offset 0/4, 18 % | `archive/look.lua` |
| Unfocused: rule.faint border, smaller shadow 10 % | `inactive_border` and `shadow.color_inactive` |
| Corner radius 0, opacity 100 %, no dimming | `rounding = 0`, `inactive_opacity = 1`, `dim_inactive = false` |
| 28 px title bar, paper.card, 1.5 px rule, Courier 12 | hyprbars plugin (`look.lua`) |
| Three ink dots, no red, yellow or green | three `ink.faded` buttons: close, maximise, drawer |
| Title graphite, unfocused faded | `col.text` plus the `hyprbars:title_color` rule for unfocused windows |
| Tiling (dwindle); small tools float centred at fixed sizes | `small_tools` in `archive/rules.lua` |
| Fullscreen drops border and shadow | the `archive-fullscreen` rule (and no title bar) |
| Urgent: accent.ink border and a stamp on the workspace number | a tag on `window.urgent` plus a rule; the ring stamp in `Workspaces.qml` |
| Drawer = scratchpad, `` Super + ` `` | `special:drawer` |

**Different from the spec:**

- The unfocused border is 2 px, not 1.5. Hyprland has one integer
  `border_size`, so the colour alone marks the difference.
- The unfocused shadow uses the focused shadow's size with a lighter colour.
  Hyprland has `color_inactive` but no separate range or offset.
- The title bar has three dots and no right-hand dash. hyprbars puts all its
  buttons on one side, so the third dot is the drawer (minimise).
- The dots don't darken on hover. hyprbars has no hover colour, only
  `inactive_button_color`.
- There's no separate rule under the title bar. With
  `bar_part_of_window`, the window's border frames the bar, which reads as the
  card's edge.
- Lowercase titles come from the app. The zsh prompt sets
  `user@host: ~/path`, and other apps show their own titles.

## 7. Core components

| Component | File |
| --- | --- |
| Index card | `qs/components/IndexCard.qml` + `Paper.qml` |
| Header band | `qs/components/HeaderBand.qml` |
| Data table | `qs/components/DataRow.qml` (cards stack rows in a Column) |
| Stamp (oval and box) | `qs/components/Stamp.qml` |
| Tape strip | `qs/components/Tape.qml` (wallpaper and pinned notifications) |
| Specimen label | `Plate.qml` (Loc. / Hab. / Leg. / Det. / Dat.) |

**Not built:** reusing the specimen label as a tooltip for window info.
Quickshell can't see hover over other apps' windows, and a bar tooltip didn't
seem worth the clutter.

## 8. Controls

| Control | File |
| --- | --- |
| Button / primary button | `qs/components/ArchiveButton.qml` |
| Toggle `ON  OFF`, pencil ring on the chosen word, pencil underline on hover | `qs/components/Toggle.qml` + `PencilRing.qml` |
| Ruler slider: ticks every 10 %, numbers at 0/50/100, 3 px blue fill, graphite triangle | `qs/components/RulerSlider.qml` |
| Progress bar | `AudioRecord.qml` |
| Text input `Query: ___` with a 1 s block caret | `Catalogue.qml`, `ReadingRoom.qml` |
| List row with paper.raised fill and a 2 px accent tick | `Catalogue.qml`, `Disposition.qml` |
| Disabled: faded, struck through | `Toggle` and `ArchiveButton` `available: false` |

**Not built:** checkbox `[x]` (no surface needs one yet) and the custom
scrollbar (no shell list is long enough to scroll).

## 9. Icons

| Spec | How |
| --- | --- |
| Single-line ink sketches, 1.5 px at 18, wobble | `assets/icons/*.svg` from `tools/gen_assets.py`, recoloured live by `InkIcon.qml` |
| Pencil-shaded weather | `assets/weather/*.svg` (hatching at 35–45 % alpha) |
| Sprig glyph = launcher button and Time Record decoration | `assets/icons/sprig.svg` |
| When in doubt, a word | Toggles, Profile, Sheet and Grain rows are typed words |
| App icons in monochrome graphite | Papirus for GTK apps, as the mockup lists. The Catalogue is text-only, so colourful icons never appear in the shell |

## 10. System surfaces

| Surface | File |
| --- | --- |
| Footer strip | `qs/modules/bar/Bar.qml`, `Workspaces.qml`, `Status.qml` |
| Card Catalogue | `qs/modules/launcher/Catalogue.qml` |
| Correspondence | `qs/modules/notifications/Correspondence.qml`, `Letter.qml`, `qs/services/Notifs.qml` |
| Instrument reading (OSD) | `qs/modules/osd/Instrument.qml` |
| Ledger | `qs/modules/calendar/Ledger.qml` |
| Instrument card | `qs/modules/quicksettings/InstrumentCard.qml` |
| Audio Archive | `qs/modules/records/AudioRecord.qml` |
| Disposition | `qs/modules/power/Disposition.qml` |
| Reading Room, REJECTED / ADMITTED | `qs/modules/lock/ReadingRoom.qml`, `qs/pam/password.conf` |
| Critical: stays, madder URGENT stamp | `Letter.qml` |
| Popups rise from the bar | `qs/components/BarPopup.qml` |

## 11. Motion

| Event | How |
| --- | --- |
| Curves `place`, `lift` | `hl.curve` in `look.lua`; `Theme.place` / `Theme.lift` |
| Window opens 220 ms / closes 140 ms | `windowsIn` 2.2, `windowsOut` 1.4 (`popin 97%`) |
| Focus change 160 ms | `border` 1.6, `fade` 1.6 |
| Workspace switch: 320 ms slide 15 % with fade | `workspaces` 3.2 `slidefade 15%` |
| Popup from the bar: 8 px, 180 ms | `BarPopup.qml` |
| Stamp: 1.12 → 1.0, 90 ms | `Stamp.press()` |
| Clock digit: fade out, type in, 120 ms | `TimeRecord.qml` `Digit` |
| Day ↔ night: 2 s crossfade | `Theme.night` animates every colour |
| Reduced motion: a 100 ms fade everywhere | `"reducedMotion": true` |

**Different from the spec:**

- Windows "rise 12 px" is approximated by Hyprland's `popin 97%` (a 3 %
  scale-in with fade). Hyprland has no rise-and-fade style.
- Only the shell crossfades for 2 s. Window borders change over about 160 ms
  after Hyprland reloads, and GTK, Qt and the terminal switch instantly,
  because apps can't crossfade their palettes.

## 12. Sound

| Spec | How |
| --- | --- |
| Theme `archive`, freedesktop names | `.local/share/sounds/archive/` (`index.theme`; files go in `stereo/`) |
| Played by the shell | `qs/services/Sounds.qml` (`pw-play`) |
| Mixing: mono, 48 kHz, −24 LUFS, −12 dBFS, 10 ms fade | `archive-sound-prep` |
| Silent on purpose | Nothing plays on typing, focus, windows or workspaces |

The sound files aren't bundled. Recording your own is the spec's
recommendation.

## 13. Wallpaper and catalogue numbers

| Spec | How |
| --- | --- |
| Text-free plate, labels typed by the shell | `Plate.qml` + `qs/services/Plates.qml` |
| 7–14 plates, a new one each day | `archive-plate import`, rotated by day of the year |
| Day version / cyanotype night version | One ink mask, inked graphite by day or cream at night, plus a silhouette photogram at night |
| Time Record No. = YY + day of the year | `Clock.timeRecordNo` |
| Meteorological No. = pressure (hPa) | `Weather.pressure` |
| Audio No. = release year | `Media.year` (from `xesam:contentCreated`) |
| Specimen and stamp No. = plate id | `Plates.number` |
| Tab. = ISO week in Roman numerals | `Clock.tabNumeral` |
| Stamp year in Roman numerals | `Clock.yearNumeral` |

The starter plate is procedural (`tools/gen_plate.py`), so it's a stand-in
for real public-domain plates.

## 14. Night mode: cyanotype

| Spec | How |
| --- | --- |
| Night tokens | `Theme.nite`, `palette.lua` `night`, `gen_themes.py` |
| White silhouette, vein detail | The plate's ink in cream plus `silhouette.png` at 16 % |
| Pale stamps | Stamp opacity drops to 45 % at night |
| Stronger grain | `Theme.grainDark` / `grainLight` rise with `night` |
| Sunrise and sunset, fixed times for Singapore | `archive-mode` + `archive-mode.timer`, with `dayStart` / `nightStart` |
| The key holds until the next boundary | `archive-mode toggle` writes `mode-hold` |

## 15. Implementation map

As specified: Hyprland for windows (Lua config, 0.55+), Quickshell for
everything else, built from scratch with one `Theme.qml`. The notification
server is Quickshell's own, and the lock screen uses `WlSessionLock`. foot,
adw-gtk3 with custom CSS, qt6ct, and a systemd user timer for day and night.
