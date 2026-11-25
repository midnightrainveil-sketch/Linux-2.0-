# Magnetic 88

`ultra-theme set retro-futurism`

Magnetic 88: a Japanese future grown out of the 1980s.
Gadgets in steel, cream and sage with e-ink screens.

![The evening train](preview.jpg)

## Done so far

- **Wallpaper**: the girl on the evening train, and the city going by
  outside her window: a long sunset over the river (`art/WindowView.png`,
  made to loop without a seam) slides past behind the glass, under the
  ceiling lights reflected in it. It comes round once every 90 seconds
  (`"windowSeconds"` in `~/.config/ultra/retro-futurism/settings.json`;
  0 holds it still) and stops while a window is fullscreen or covers the
  whole glass.
- **The ride**: the car sways very slightly all the time (slow waves that
  never fall into a beat; the city outside, being far off, moves less than
  the car), and every 18 to 45 seconds it runs over a rail joint: da-dum,
  da-dum, a short jolt from each axle of the front bogie and then the back
  one. `"sway"` and `"bumps"` (true / false) in settings.json.
- Her mole is a little clearer, on the wallpaper as on the lock screen.
- **Lock screen** (`modules/Lock.qml`): her room at night, the Suisei clock
  on the night stand live. Any key or click blurs the room and drops the
  Personal Access Pass down (`art/Login1.png`; the device itself is
  `art/Login0.png`, lifted off by `tools/make_pass.py`): your name, today,
  a dot for each key, what it is doing (ready, checking, denied,
  boarding). Let in, the pass shoots back up, the blur clears, the room
  fades into the desk (the city outside the window where the desk has it)
  and the taskbar comes up from below. The pass's buttons: ‖ sleep, POWER
  shut down (twice), USER clear, SESSION put the pass away, ◀◀ one key
  back, the roller and ▶▶ enter.

![The lock screen](preview-lock.jpg)

- **Taskbar** (`modules/Taskbar.qml`): the mock-up itself,
  `art/TaskbarEg.png`, along the foot of the screen, with what it shows
  drawn live where the mock-up has it (`tools/make_taskbar.py` cuts the bar
  out, erases its contents and splits it in three: the ends, and a slice
  of the band stretched to the screen's width). On the left the cartridge port (the
  slot the app cartridges go in; click it for the launcher, its lamp lit
  while the launcher is open); workspaces 1 to 6 (a dark dot where windows
  are, the red line under the one in view; click, or scroll to step); the
  sage band with its red line, MAGNETIC 88 and the Arch logo (click:
  the power menu); and Wi-Fi (click: nmtui), volume (scroll; click mutes),
  battery (one smooth bar and its percentage): click any of the three for
  the control deck, scroll for the volume; and the time.
  The cartridge port is painted into the picture by the tool (a slot in a
  chamfered steel bezel with two screws, the cartridges' four gold contacts
  on its floor); its contacts glow warm while the launcher is open. The
  figures (workspaces, battery, time) are in Barlow (SIL Open Font License,
  shipped with the theme).

- **Window rims**: every window has the taskbar's own chrome rim round it,
  at the taskbar rim's depth (17 px: its 22 px at the bar's size), drawn by
  Hyprland itself as it draws its own borders: the theme's **chromerim**
  plugin (`~/.local/share/ultra/retro-futurism/plugins/chromerim`, built for
  your Hyprland by `ultra-rim`, at setup and at login when Hyprland
  changes). So the rim moves, slides and resizes with its window in the same
  frame, at any size. The rim is the taskbar's own chrome: its pixels, cut
  from its picture by `tools/make_rim.py` (its ends' quarters for the corners,
  its straights for the edges), only scaled. The window in use has the bright rim, the
  others a shade darker. Until the plugin is built (and round X11 windows) the shell
  draws the same rim (`components/Frame.qml`). The gaps in
  `hypr/theme/look.lua` go with the frame values in `theme/Theme.qml`.
  `ultra-rim status` says whether it is built and loaded; `ultra-rim off`
  leaves it out. A window rule `chromerim:no_rim` leaves one window without.
- The taskbar runs the rims' full width (its middle band stretches) and
  hides below the screen while windows are open: take the pointer down to
  the bottom edge and it slides up over the windows, which stay where they
  are. Its tube then lies on the foot of their rims: its ends and foot on
  theirs, its round ends on their bottom corners (the windows are rounded
  21 px, so the rim round them bends as the taskbar's ends do).

- **Widgets** ([docs/widgets.md](docs/widgets.md)): the gadgets, called up
  over the blurred desk (Super + R the typewriter, Super + Space the
  launcher, Super + C the organizer ...) and worked with keys and clicks.
  Built so far: the **control deck** (click the taskbar's Wi-Fi, volume or
  battery): Wi-Fi and Bluetooth switches, power mode, refresh rate, lock
  time, volume and brightness faders, and a screen with the battery and the
  state of each; and the **clock** (click the taskbar's time): the time and
  date, an alarm and a timer that ring even with the clock put away. The
  **power** menu (the laptop's power button, or the Arch logo): the same
  silver device as the pass, its roller turned by the wheel; and the
  **launcher** (Super + Space): the Kairo cartridge launcher, your apps as
  cartridges on its rail, the wheel or the arrows to choose, typing to
  search, Enter to launch: the taskbar slides across on its arm, the
  slot's bracket lowers the cartridge into its port on the launcher's rods
  and the bar slides home; a cartridge stays there, the app of the window under the pointer.
  The **cassette vending machine** (Super + V): every song in `~/Music`
  (any folder below it; or the `music` setting) is a cassette on its
  shelves, in one of its eight shells, its title on its label. The wheel,
  the arrows or typing choose and search, as in the launcher; the lift's
  carriage rides its screw to the chosen shelf. Enter (or SELECT / EJECT)
  dispenses it: the carriage draws it off its shelf, carries it down and
  drops it in the tray, step by step on the e-ink screen, and the
  **cassette player** (Super + A) comes up and takes it in. The player's
  keys work (PLAY stays down while it runs, REW / FF wind while held,
  STOP/EJ stops and, again, ejects, REC opens the machine; with none of
  yours in, it plays along with whatever else is playing, a browser's video
  or a music app, its keys and knob that player's); the reels
  turn, the tape winds from spool to spool as the song goes, the meter and
  the lamp light, the knob is the volume. The music is a windowless mpv
  (`ultra-tapes`; with `mpv-mpris` it is an ordinary player for the media
  keys and the meters too). The rest are placeholders (their mock-up)
  until made.

- **Notifications** come on the KAZE pager (`modules/Pager.qml`,
  `services/Notifs.qml`): it slides in from the top right corner with the
  notification on its e-ink screen (the app's mark in ink: Simple Icons'
  brand marks, CC0, for the well-known apps, else the app's own icon in
  greys), and out again after a few seconds (an urgent one stays; it waits
  while the pointer is on it). A tap opens what it is about, right-click or
  CLEAR clears it, ◀ ▶ page through the earlier ones, ALL CLR clears them
  all. Super + N brings it up to look through them (the arrows, Enter,
  Delete, Shift + Delete, Esc); Super + Shift + N clears all, Super + Alt +
  N is Do Not Disturb (they are kept, quietly). The history (60) is kept
  across restarts. Its picture is cut by `tools/make_pager.py`.

- The **organizer** (Super + C; `widgets/organizer`, `services/Organizer.qml`):
  the SHINWA digital planner, its e-ink screen drawn live (nothing on it
  is a picture but the ginkgo and the icons, drawn by `tools/make_organizer.py`).
  CALENDAR (the month, dots for events, squares for tasks due; the day,
  UPCOMING, REMINDERS below), AGENDA (the coming weeks), TASKS (a to-do
  list) and NOTES. Start typing anywhere to add one; Enter opens, Space
  ticks, Delete removes, Tab or the keys below the screen change view, the
  rocker steps, the round key is "new". An event or task can have a date,
  a time and a reminder (at the time, minutes, hours or days before): the
  reminders come as notifications on the pager, whether the organizer is up
  or not, and a tap on one brings it up. Everything is kept in
  `~/.local/state/ultra/retro-futurism/organizer.json`.

- The **research station** (Super + R; `widgets/typewriter`, `services/Research.qml`,
  `ultra-research`): the SHINWA RS-2012 typewriter. A long e-ink tablet stands
  in its slot, a strip of it showing for everyday work; PULL OUT on it (or
  the round knob, or F11) slides it up out of the slot, full length, for big
  work, the machine sinking away below, and PUSH IN puts it back. Type a
  question, Enter: the web's results (DuckDuckGo's plain page: no key, no
  account; Google's own results need a paid key), each opened in your
  browser with Enter or a click and marked READ; the progress bar counts
  them. SOURCES (the results by address), NOTES (yours, per session),
  ARCHIVE (every session) and EXPORT (the session as Markdown in
  `~/Documents/Research`). Its keys go down as you type, its springs give,
  its platen knobs turn and its carriage runs along the line; its feed lamp
  pulses while it searches. Its pictures and icons: `tools/make_typewriter.py`.

Every gadget is built now.

(The theme was begun as a copy of Viewfinder's box; everything of Viewfinder's
look is gone from it now.)


## How the lock screen is made

The lock screen is a station platform at dusk: she waits for the train
whose headlights are coming round the bend. `tools/make_lock.py` writes
`lock.jpg` (`art/Lock-Platform.webp`) and `lock-boarded.jpg`
(`art/Lock-Platform-Empty.webp`, the same platform without her) and the
glows laid on it (`lock/`). On it, `modules/Lock.qml` breathes the
headlights' glow, and lights the signal red for a wrong key, then green
as you are let in, when the platform fades to the one without her: she has
boarded.

The clock is written in Japanese, top to bottom, up in the sky to the
right (二十一時 / 四十六分, the hour's column first), in Shippori Mincho;
beside it, down a fine rule, the time in figures, the day and the date in
Cormorant Garamond, and along the foot, in the same serif, how to get in
and the machine's state (`components/LockOverlay.qml`). Both fonts are
under the SIL Open Font License, cut down to what they are used for (the
mincho to the clock's characters). `art/Lock-Car.webp`, the empty car, is
kept for later.

## How the window's view is made

- The wallpaper is `art/Wallpaper-Extended.jpg` (3840 x 2160): the old
  `art/Retro-Futuristic-Wallpaper.png` zoomed out, the car round it painted
  on (that picture is this one's 539,216 to 3300,1944, scaled 1.742).
- `tools/make_poster.py` prints the second poster again (the zooming out
  had copied the first into it): Mt. Fuji under a striped sun, a bullet
  train below, in the first poster's own inks, on its paper as it hangs
  there (its light, the frame's shadow and its grain kept).
- `tools/make_window_loop.py` turns `art/WindowView.png` into
  `window-view.jpg`: each column moved up or down so the viaduct runs level,
  then the right end joined to the left along the cut where the two look
  most alike (it follows a tower's edge), so the strip repeats without a
  seam; and 140 rows of evening sky on top, for the tall window.
- `tools/make_wallpaper_front.py` makes `wallpaper.jpg` (the whole picture)
  and `wallpaper-front.png`, only the window (1540,60 to 3010,950): its glass
  see-through, measured on the picture (the edges where the dark seal meets
  the glass, the corners' own radii), except where she is in front of it.
  Her edge is a closed-form matte (pymatting) between what is surely her,
  surely the view (its cool sky, its lit windows) and the band between,
  wide where her hair is; her loose strands kept for the matte to weigh;
  her colour there with the view behind taken back out; bits of the old
  view that are not her taken out; the reflected ceiling lights kept.
- `tools/make_cassette.py` cuts the cassette player's moving parts from
  `wallpaper.jpg` (`cassette/`): each reel as a disc,
  centred where it looks most alike turned a quarter (so it spins without
  a wobble), and each level meter's window with its painted bars taken out.
  While music plays, `components/CassettePlay.qml` turns the reels and
  lights the meter's bars to the music (`services/Spectrum.qml`: six bands
  from `cava`, with a stand-in if cava is missing).
- `tools/make_tapedeck.py` cuts the cassette player widget from
  `art/CassettePlayerWidget.png` (`widgets/cassette/`): the body with its
  window, meter, lamp and knob emptied, each key, a reel's hub, the glass's
  streaks, and its cassette in the vending machine's eight colours.
  `tools/make_vending.py` cuts the vending machine (`widgets/vending/`):
  the body with its shelves, numbers, lamps, column, tray and screen
  emptied, the carriage, the column's head, the tray's clips, and the
  eight cassettes with their titles taken off (`shells.json`: where a
  title goes on each).
- The pointer cursors are [Bibata Modern Ice](https://github.com/ful1e5/Bibata_Cursor)
  by ful1e5 (GPL-3.0, its licence beside them), recoloured to the theme's
  cream with a warm dark outline by `tools/make_cursors.py`
  (`home/.local/share/icons/Magnetic88`; sizes 24 to 64 px, the busy
  cursors at half their frames). Hyprland, GTK and every app use it, at
  28 px (`"cursorSize"` in the theme's settings.json for another). The
  first, chrome-and-sage design is `art/Cursors.png`.
- `tools/make_desk_cassette.py` cleans up the cassette player in her hands
  (called by `make_wallpaper_front.py` before the picture is saved): the
  image generator's made-up lettering painted out and written again
  (MAGNETIC 88 on its plate, STEREO under its window), its keys' symbols
  drawn clean, its cassette given a label (A · NIGHT TRAIN), two mushy
  shapes made round buttons, and its reels drawn again (a brown tape pack
  round a cream six-toothed hub), written too as the reels that turn
  (`cassette/home-reel-*.png`).
- The system's programs (Files, Text Editor, gThumb, the sound, Bluetooth
  and network settings, Timeshift: GTK, and Qt ones through it) are made
  the SYSTEM CONTROL DECK's screen: its cool grey glass and dark ink (soft
  contrast, no paper warmth), a faint shadow under the glass's top edge,
  thick ink rules under the title bar and beside the sidebar, ink-ruled keys
  and boxes, what is chosen lit as the deck lights a row (an ink bar with the
  glass's grey in it); the screen's VT323 for the device's words (titles,
  headings, sidebar, address, keys), Inter for what you read; nothing in
  colour but the file icons (`home/.config/ultra/retro-futurism/gtk.css`,
  put in place by `ultra-look` at login). Their files and folders have the
  theme's own icons (`art/FileIcons.png`, cut by `tools/make_file_icons.py`
  into the icon theme `Magnetic88-Files`: twenty icons, linked to some two
  hundred file types and places; programs' icons from Papirus).
- `modules/Backdrop.qml` lays the whole picture, the view in the glass
  (1566,76 to 2982,922 of the picture) and the window over it.

## The terminal

Ghostty (`home/.config/ghostty/`): an e-ink screen like the theme's devices,
dark ink on light grey glass, inside the windows' chrome rim and nothing
else. `eink.glsl` gives the glass its grain, a soft light from the top
left, the rim's shadow along its top and the ink spreading a hair, as e-ink
does; it is drawn once per change of the text (nothing animates). The
palette is greys and a few muted inks (the deck's indigo, a dull rust).

The greeting is `ultra-card` (`home/.local/bin`): in black and white,
heavy as e-ink is (thick borders, solid gauges, Medium and ExtraBold type),
each fact with its icon (Nerd Font symbols, which Ghostty carries), a
picture borderless beside the boxes. Hyprland tiles terminals by halving
the newest, so it has a layout for each size and takes the richest that
fits the width and the height: wide (one terminal), classic (two), compact
(three), a column (four), a strip (five, and the desk terminal), and the
picture with the time (six on). The picture is the `card-art` folder,
made by `tools/make_card_art.py` from any drawing (`art/Card-Cat.webp`, the
sleeping cat): the drawing itself where the terminal shows pictures
(Ghostty or kitty, not over SSH or in tmux), quadrant blocks elsewhere.

    python3 tools/make_card_art.py art/Card-Cat.webp \
        home/.local/share/ultra/retro-futurism/card-art

## The terminal widget

A terminal pinned low on the left of the home screen, in the screen's shape, its rim always lit, floating and
untouched by Hyprland's tiling (`ultra-desk`, `hypr/theme/rules.lua`; on
by default, `"deskTerminal": false` in settings.json for none). Its shell
lives in a tmux session of its own (`desk.tmux.conf`: no status line, no
prefix key), so Super + F on it opens a fullscreen view of the same shell
over it, another window onto the session: what runs, its history and the
screen carry over, the widget stays where it was, and closing the view
goes back to it. The session outlives the widget: closing it and opening
it again (Super + D) picks the shell up where it was. The card's picture
shows through tmux by kitty's Unicode placeholders.

