# Retro Futurism

`ultra-theme set retro-futurism`

*In the works.* Cassette OS: a Japanese future grown out of the 1980s.
Gadgets in steel, cream and sage with e-ink screens.

![The evening train](preview.jpg)

## Done so far

- **Wallpaper**: the girl on the evening train.
- **Lock screen**: her room at night. The Botsync clock on the night stand
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
