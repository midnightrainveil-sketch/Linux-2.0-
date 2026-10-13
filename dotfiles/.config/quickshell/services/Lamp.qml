pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The desk lamp: at night a warm pool of light follows the pointer over the
// desk, and the rest of the sheet sinks a little into the dark. It is moved
// by the pointer only over the desk itself (the wallpaper and the record
// cards); while you work in a window it stays where you left it, as a lamp
// would. On or off is kept in ~/.local/state/archive/lamp.
//   qs ipc call lamp toggle      (Super+Alt+L, or the Instrument card)
Singleton {
    id: root

    readonly property bool isOn: file.text().trim() !== "off"
    // where the light falls, in the coordinates of that screen
    property string onScreen: ""
    property real atX: -1
    property real atY: -1

    function moveTo(screenName: string, px: real, py: real): void {
        onScreen = screenName;
        atX = px;
        atY = py;
    }

    function set(want: bool): void {
        const path = Settings.stateHome + "/archive/lamp";
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && printf '%s\\n' \"$2\" > \"$1\"", "sh", path, want ? "on" : "off"]);
    }
    function toggle(): void { set(!isOn); }

    FileView {
        id: file
        path: Settings.stateHome + "/archive/lamp"
        watchChanges: true
        onFileChanged: reload()
    }
}
