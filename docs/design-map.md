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
| Courier Prime, sized off the reference at 1920 px (about 1.4x the spec's tokens): titles 16 regular caps +10 %, data and labels 16, small 15, clock 92 stretched 1.2x upright (tall typewriter figures), temperature 37 stretched 1.45x | `Theme.size*`, `Theme.clockStretch`; `InkText` adds tracking and ink spread |
| Courier Prime in the terminal, as on the reference card (the spec names IBM Plex Mono; the reference shows typewriter type) | foot (`font=Courier Prime:size=14.5`, IBM Plex Mono behind it for box-drawing and symbols); `fonts.conf` monospace for other apps stays IBM Plex Mono |
| The clock's worn typewriter figures | `TimeRecord.qml` `Digit`: Courier Prime through `assets/ink-wear.png`, a worn-ribbon mask (patchy ink, pale streaks, pinholes) |
| Desk terminal: name in bold with a rule, "Key: value" lines, six ink swatches | `fastfetch/config.jsonc`; swatches are palette slots 16-21, set per mode in `foot.ini` |
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
| Ink: typed text reads heavier, like ink pressed into paper | `qs/components/InkText.qml` (two faint offset copies, `spread`) |
| Stamps: uneven ink, ±8°, 75–85 % | `qs/components/Stamp.qml` (knock-out specks and scuffs) |
| Foxing: 3–6 spots, wallpaper only | `qs/modules/background/Plate.qml` |
| Paper over everything (windows too) | `.config/hypr/shaders/paper.frag`, on by default, toggled by `archive-grain` / `Super + Shift + G` |

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
| Left desk ~35 %, centre ~35 %, right ~25 %, footer 40 px | Desk terminal rule (`archive/rules.lua`: 31.25 % of the screen wide and 16:9 with its title bar, at 1.9 % / 16.4 %; clear of the plate's big leaf; its own 10 pt type so the fastfetch card fits), plate box 0.375–0.665, `Theme.recordWidth` 480, `Theme.barHeight` 40 |
| The desk stays as in the reference, and comes back | Record cards are `DeskCard`s (`components/DeskCard.qml`): drag anywhere, right-click to put away; `services/Desk.qml` remembers which are away. `archive-desk` (bar button after the workspaces, `Super + D`) calls `qs ipc call desk restore` and brings the desk terminal to the current workspace at its place, or reopens it |
| 8 px grid; margins 32, gaps 24, padding 16, header 10/14, rows 30 | `Theme.qml` |
| Window gaps 8 between, 24 to the edge | `gaps_in = 4` (Hyprland doubles it between windows), `gaps_out = 24` |
| 16:10: extra height as breathing room | `Records.qml` spreads the spare height between the cards, never adding one |

## 6. Windows

The reference window was measured at 1920 px, and the config follows the
measurements rather than the spec text where the two disagree.

| Reference | How |
| --- | --- |
| No hard frame: a torn, chipped paper edge, lit from the top left (palest on top, darkest bottom and right), with a light bevel inside and pale fibres where it is torn | archivebars' **deckle** (`deckle.cpp`, `DeckleDeco.cpp`): a card 6 px larger than the window, laid out of repeating edge tiles; `deckle_*` in `look.lua`, colours `edge_top`, `rim_bottom`, `bevel` in `palette.lua`. Hyprland's border is off (`border_size = 0`) |
| Aged paper: darker toward the edges, small tears, wrinkles, creased corners | the deckle's second layer, drawn over the window's padding: `deckle_tone` (`edge_tone`), `deckle_chips`, `deckle_creases` |
| Shadow falling down and to the right | the deckle's own shadow (blur 4.5, offset 1.5/3, 40 %) plus a tight contact shadow under the edge, so the shadow follows the torn outline. Hyprland's shadow is off |
| Square corners, just worn | the deckle's corner tiles; `rounding = 0` |
| 46 px paper title bar: three dark dots 11 px, 21 px apart; title in Courier Prime 18; "–" at the right; a ruled line under it, 11 px in from each side | **archivebars** (hyprbars + `rule_*` + `right_icon*`, built by `archive-bars`), configured in `look.lua` |
| Dots: close, maximise, drawer. "–": drawer | buttons and `right_icon_action` |
| Paper texture and slightly ragged ink inside the window | the paper screen shader `shaders/paper.frag`, on by default |
| Focus lifts the card | focused: darker edge and 40 % shadow; unfocused: lighter edge, 24 % shadow, faded title |
| Fullscreen drops the bar, rim and shadow | `archive-fullscreen` rules |
| Urgent: accent.ink border and a stamp on the workspace number | a tag on `window.urgent` plus a rule; the ring stamp in `Workspaces.qml` |
| Drawer = scratchpad, `` Super + ` `` | `special:drawer` |

**The torn edge.** Hyprland's own borders are straight, so the edge is drawn
by the plugin instead. Each side is cut from short strips (160 px, three
variants) whose torn line starts and ends on the same baseline, so they join
seamlessly in any order and any number. Corners are their own tiles, and so
are the creases. There are two layers: under the window (shadow, paper,
outline, bevel, chips with their torn fibres, worn corners) and over it (the
aged edge, tears, wrinkles, creases), and a tear's slit lines up with its
notch because both layers are cut from the same strip. Every tile is drawn
once per look (colours, monitor scale, focus) and reused for every window
and size. Each window picks its own sequence of variants and creased
corners, so no two cards look alike.
`tools/deckle-preview.cpp` renders the same tiles outside Hyprland.

Without the plugin the fallback is a straight 1 px rim with a top-to-bottom
gradient (`border_size = 1`, `rim_top` → `rim_bottom`), Hyprland's shadow and
`rounding = 2`.

A window whose own background is not the paper colour (a browser, say) shows
its straight edge inside the card, with a 4 px paper margin around it. To
remove the card from such an app, add
`hl.window_rule({ match = { class = "..." }, ["archivebars:no_deckle"] = true })`.

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

The starter plate is `art/wallpaper.webp` used whole, as you asked: its own
typed header, labels, stamp and tape stay (`"sheet": true` in its
`meta.json`), so the shell types nothing over it. `tools/import_wallpaper.py`
upscales it, tones its paper to the desk grey, and prints a cyanotype version
for night (pale ink on Prussian blue, the paper's mottling kept); `Plate.qml`
crossfades between the two. Note that the sheet's own text says "Herbarium"
and "HERB. REG. BOT.", which the spec keeps off the screen; it is shown
because the picture is yours. Plates imported with `archive-plate` carry no
text, and for those the shell types the labels live (`Tab.` week numeral,
Specimen No. and so on).

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
