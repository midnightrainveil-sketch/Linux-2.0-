# Widgets

The gadgets of Cassette OS (the typewriter, the organizer, the cassette
player ...) are widgets: called up over the desk, blurred and dimmed behind
them, and worked with the keyboard and the mouse until put away (Esc, a
click outside, or the same key again).

## Where things are (`home/.config/quickshell/`)

```
widgets/index.json          every widget: id, name, its key, callable or not, its mock-ups
widgets/<id>/Main.qml       the widget itself
widgets/<id>/*.png, *.jpg   its pictures (preview.jpg: the mock-up, while it is a placeholder)
services/Widgets.qml        which widget is up: open(id), toggle(id), close()
modules/WidgetStage.qml     the stage: blur and dimming, the animation in and out, the keyboard
components/Widget.qml       what every widget is built on
components/WidgetStore.qml  a widget's saved state
components/WidgetPlaceholder.qml   the stand-in until a widget is built
```

## The widgets

| id | name | key | mock-ups |
| --- | --- | --- | --- |
| `typewriter` | Typewriter | Super + R | Typewriter |
| `launcher` | App launcher (**built**) | Super + Space, or the taskbar's port | AppLauncher, AppLauncherEmpty, Cartridges |
| `organizer` | Organizer | Super + C | Calendar |
| `cassette` | Cassette player | Super + A | CassettePlayerWidget |
| `vending` | Cassette vending | Super + V | CassetteVending |
| `clock` | Clock (**built**) | Super + W, or click the taskbar's time | ClockWidget |
| `controls` | Control deck (**built**) | Super + S, or click the taskbar's Wi-Fi / volume / battery | ControlDeck |
| `power` | Power (**built**) | the laptop's power button, the Arch logo, Super + Shift + Escape | Power |
| `pager` | Notifications | none: the shell brings it up | Notification |

Built: the control deck, the clock, power and the launcher. The rest are placeholders: their mock-up, and a tag
that shows the last key or click they were given.

## Where they come up

`"placement"` in the index: `"center"` (the default) in the middle of the
screen, the desk blurred and dimmed behind; `"taskbar"` over the taskbar's
right end, its body's right edge on the bar's, over the windows, nothing
blurred (the control deck). A widget with a clear margin round its picture
(a shadow) says so with `airRight` / `airBottom`, so its body is what lines up.

From a terminal: `qs ipc call widget toggle typewriter`, `... widget close`,
`... widget list`.

## How the control deck is made

`tools/make_controldeck.py` turns `art/ControlDeck.png` into `deck.png` (the
deck off its white, everything that changes erased and refilled from what
lies round it) and the parts that move: the buttons up and lit, the switch
knob, the fader and lock thumbs. `widgets/controls/Main.qml` lays the live
parts in the mock-up's own pixels and scales the whole deck once, so each
sits exactly where the picture has it. It reads and sets: Wi-Fi and
Bluetooth (`services/Net.qml`), the power mode, battery (`Power.qml`), the
refresh rate, the lock time and the colour profile (`Machine.qml`: the
core's `ultra-refresh`, `ultra-idle`, `ultra-icc`), volume (`Audio.qml`) and
brightness (`Brightness.qml`).

The colour profile is the machine's, not the theme's: `ultra-icc` links it at
`~/.config/ultra/icc/<screen>.icc` and `hypr/ultra/machine.lua` hands it to
Hyprland under every theme; the deck's screen shows the one in use.

## The clock

`tools/make_clock.py` lifts `art/ClockWidget.png` off its white, makes its
display glass and date strip anew (a smooth fit of their own colour, so no
ghost of the mock-up's figures is left), turns the lit lamp off and the
brand into SUISEI. `widgets/clock/Main.qml` draws the digits
(`components/SevenSegment.qml`, the lock screen's, set to this size) and the
date strip (`DotMatrix.qml`). The alarm and the timer are
`services/Alarms.qml`, not the widget: they keep going with the clock put
away, ring with a sound (`sound-theme-freedesktop`, played by `pw-play`), a
notification and the clock brought up, and are kept in
`~/.local/state/ultra/retro-futurism/clock.json`.

Its controls: MODE (M, Tab, or a lamp) TIME / ALARM / TIMER; SET (S, Enter)
sets the alarm's hour then minute (and turns it on), or the timer's minutes
then seconds; the date strip (Space) turns the alarm on or off, starts or
pauses the timer; Up / Down or the wheel over a pair of digits steps it;
R resets the timer. Ringing: any key or click stops it, MODE or Z snoozes
the alarm 9 minutes.

## Power, and the device it shares with the lock screen

`components/PassDevice.qml` is the silver Kairo device (`art/Login0.png`,
`assets/pass.png`): its picture, one glow for what is put on its face, its
buttons as signals, and its roller, drawn as a turning cylinder (the wheel
over the device turns it a ridge a notch and says so with `rolled`). The
lock screen's access pass and `widgets/power` are both built on it.

Power: Lock, Suspend, Log out, Restart, Shut down. The wheel (the roller
turns with it), the arrow keys, ◀◀ / ▶▶, 1-5 or a click choose; Enter,
Space, the roller or a click on the chosen line do it. ‖ POWER USER SESSION
choose Suspend, Shut down, Log out, Lock. It opens on Suspend; Restart and
Shut down light the red lamp.

## The launcher, and the cartridge in the port

With the launcher up, the taskbar moves over its stage (out of the blur) and
slides right on its arm (drawn in `modules/Taskbar.qml`, mounted behind the
bar's home place) until its port is under the launcher's slot
(`Cartridges.slotX`, which the launcher gives once it is up). The port is
as large as the slot (a cartridge is the same size in both), so the bar
has six workspaces. On Enter the app starts and the slot's lower bracket
(`widgets/launcher/bracket.png`, cut out by `tools/make_launcher.py`, the
body filled in behind it) carries the cartridge straight down on the
launcher's own rods (a slice of each, stretched), over the bar, into its
port, with a small knock as it seats (while it works `modules/Lifter.qml`
draws the bracket, the rods and the cartridge over the taskbar, where the
launcher had them; the cartridge is cut off at the port's mouth); there it is let go
(`Cartridges.land`: the bar shows it from then), the bracket goes back up,
quickly, the launcher is put away and the bar slides home.

The bar keeps a cartridge standing in the port (its panel is taller for it,
its pointer area just the tube and the cartridge): the app of the window
under the pointer (focus follows the pointer, so `Hypr.activeClass`), else
the last one launched; a click on it opens the launcher. The bar up for a
widget lies over the windows; only the pointer at the screen's foot makes
room for it.

## Building one

`widgets/<id>/Main.qml` is a `Widget` with its own parts in it:

```qml
import QtQuick
import qs.components
import qs.services

Widget {
    id: self
    widgetId: "typewriter"
    preferredWidth: 1170; preferredHeight: 780   // its size on a 1920-wide screen

    Image { anchors.fill: parent; source: self.art("body.png") }

    // it has the keyboard while up
    Keys.onPressed: e => { /* a key */ }
    MouseArea { /* clicks, drags, the wheel */ }

    // its own saved state, kept across restarts
    Component.onCompleted: page = store.get("page", 1)
    onPageChanged: store.set("page", page)
    property int page: 1

    onOpened: { /* up: start what moves */ }
    onClosing: { /* going: stop it */ }
}
```

What a widget is given:

- `store.get(key, fallback)` / `store.set(key, value)`: its state, in
  `~/.local/state/ultra/retro-futurism/widgets/<id>.json`.
- `art(name)`: a picture in its own folder.
- `close()`; Esc already closes (a part that wants Esc for itself takes it
  with `Keys.onEscapePressed` and leaves `close()` for later).
- `shown`, `opened()`, `closing()`: to start and stop what moves.

The stage fits it to the screen (scaled down if it is too large), brings it
up with a short rise and settle, and loads it only while it is up.

## Adding one

1. A folder `widgets/<id>/` with `Main.qml` (copy a placeholder's).
2. An entry in `widgets/index.json`.
3. Its key in `hypr/theme/binds.lua`: `hl.bind(mod .. " + X", widget("<id>"), ...)`.
