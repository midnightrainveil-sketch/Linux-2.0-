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
| `launcher` | App launcher | Super + Space (and the taskbar's port) | AppLauncher, AppLauncherEmpty, Cartridges |
| `organizer` | Organizer | Super + C | Calendar |
| `cassette` | Cassette player | Super + A | CassettePlayerWidget |
| `vending` | Cassette vending | Super + V | CassetteVending |
| `clock` | Clock | Super + W | ClockWidget |
| `controls` | Control deck | Super + S | ControlDeck |
| `power` | Power | Super + Shift + Escape (and the Arch logo) | Power |
| `pager` | Notifications | none: the shell brings it up | Notification |

All are placeholders for now: their mock-up, and a tag that shows the last
key or click they were given.

From a terminal: `qs ipc call widget toggle typewriter`, `... widget close`,
`... widget list`.

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
