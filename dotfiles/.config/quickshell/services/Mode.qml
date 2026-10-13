pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Day / night (cyanotype) state. The single source of truth is the file
// ~/.local/state/archive/mode, written by `archive-mode` (run by a systemd
// user timer at sunrise / sunset, or by hand). This only watches it.
Singleton {
    id: root

    readonly property bool isNight: file.text().trim() === "night"
    readonly property string name: isNight ? "night" : "day"

    function set(mode: string): void {
        Quickshell.execDetached(["archive-mode", mode]);
    }
    function toggle(): void { set("toggle"); }

    // Optional film grain screen shader (archive-grain writes on / off).
    readonly property bool grain: grainFile.text().trim() === "on"
    function setGrain(on: bool): void {
        Quickshell.execDetached(["archive-grain", on ? "on" : "off"]);
    }

    FileView {
        id: file
        path: Settings.stateHome + "/archive/mode"
        watchChanges: true
        onFileChanged: reload()
    }

    FileView {
        id: grainFile
        path: Settings.stateHome + "/archive/grain"
        watchChanges: true
        onFileChanged: reload()
    }
}
