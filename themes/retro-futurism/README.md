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
- **Lock screen**: her room at night. The Suisei clock on the night stand
  is live: the time (the colon blinks each second) and the date in its
  dot-matrix strip. The rest of the picture stays still. Type the password
  (nothing shows) and press Enter.

![The lock screen](preview-lock.jpg)

Everything else (bars, launcher, panels, power menu) is still Viewfinder's,
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
