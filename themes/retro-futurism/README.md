# Retro Futurism

`ultra-theme set retro-futurism`

*In the works.* Cassette OS: a Japanese future grown out of the 1980s.
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
- **Lock screen**: her room at night. The Suisei clock on the night stand
  is live: the time (the colon blinks each second) and the date in its
  dot-matrix strip. The rest of the picture stays still. Type the password
  (nothing shows) and press Enter.

![The lock screen](preview-lock.jpg)

- **Taskbar** (`modules/Taskbar.qml`): the mock-up itself,
  `art/TaskbarEg.png`, along the foot of the screen, with what it shows
  drawn live where the mock-up has it (`tools/make_taskbar.py` cuts the bar
  out, erases its contents and splits it in three: the ends, and a slice
  of the band stretched to the screen's width). On the left the cartridge port (the
  slot the app cartridges go in; click it for the launcher, its lamp lit
  while the launcher is open); workspaces 1 to 9 (a dark dot where windows
  are, the red line under the one in view; click, or scroll to step); the
  sage band with its red line, CASSETTE OS and the Arch logo (click:
  the power menu); and Wi-Fi (click: nmtui), volume (scroll; click mutes),
  battery (one smooth bar and its percentage; click: the next power
  profile) and the time.
  The cartridge port is painted into the picture by the tool (a slot in a
  steel bezel with four gold contacts, as on the cartridges, the red
  indicator under it, a ribbed grip); the shell lights the indicator.

Everything else (launcher, panels, power menu) is still Viewfinder's,
copied into this box, until each part gets its own design from the mock-ups
in [`art/`](art/).

## How the lock screen's clock is made

`home/.local/share/ultra/retro-futurism/lock.jpg` is `art/Lockscreen.png`
with the clock's window and date strip emptied (also kept as
`art/Lockscreen-blank.png`). `modules/Lock.qml` fills the screen with it and
places the live parts in the picture's own pixels (1671 x 941):
`components/SevenSegment.qml` in the window (100,634 to 254,711) and
`components/DotMatrix.qml` in the date strip (114,723 to 218,740).

## How the window's view is made

- `tools/make_window_loop.py` turns `art/WindowView.png` into
  `window-view.jpg`: each column moved up or down so the viaduct runs level,
  then the right end joined to the left along the cut where the two look
  most alike (it follows a tower's edge), so the strip repeats without a seam.
- `tools/make_wallpaper_front.py` makes `wallpaper-front.png`: the
  wallpaper with the glass see-through, except where she is in front of it
  (her hair is warm, the city cool: the warm region joined to her face; along
  her outline a soft matte, with the old view's colour taken back out), and
  the reflected ceiling lights kept over the glass.
- `modules/Backdrop.qml` lays the view in the glass (592,0 to 1400,403 in
  the 1585 x 992 picture) and the front over it.
