pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The machine's own settings, as the core's commands keep them (they belong
// to the machine, not to this theme, so any theme sees the same):
//   refresh       the panel's rate: "60", "120" or "auto"   (ultra-refresh)
//   lockAfter     minutes before the screen locks, or "never" (ultra-idle)
//   colour        the colour profile in use on this screen, or "none"
//                 (ultra-icc; Hyprland applies it from ~/.config/ultra/icc,
//                 hypr/ultra/machine.lua, whatever the theme)
Singleton {
    id: root

    readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")

    // ---- refresh rate
    property string refresh: "auto"
    function setRefresh(v: string): void {
        refresh = v;                                    // at once; the file follows
        Quickshell.execDetached(["ultra-refresh", v]);
    }
    FileView {
        path: root.stateHome + "/ultra/refresh"
        watchChanges: true; printErrors: false
        onFileChanged: reload()
        onLoaded: { const v = text().trim(); if (v === "60" || v === "120" || v === "auto") root.refresh = v; }
    }

    // ---- automatic lock
    property string lockAfter: "5"
    function setLockAfter(v: string): void {
        lockAfter = v;
        Quickshell.execDetached(["ultra-idle", v]);
    }
    FileView {
        path: root.stateHome + "/ultra/retro-futurism/idle"
        watchChanges: true; printErrors: false
        onFileChanged: reload()
        onLoaded: { const v = text().trim(); if (v !== "") root.lockAfter = v; }
    }

    // ---- colour profile
    property string colour: "none"
    readonly property string colourName: colour === "none" || colour === ""
        ? "NONE" : colour.split("/").pop().replace(/\.(icc|icm)$/i, "")
    function readColour(): void { iccReader.running = true; }
    Process {
        id: iccReader
        command: ["ultra-icc", "current"]
        stdout: StdioCollector { onStreamFinished: root.colour = text.trim() || "none" }
    }
    Timer { interval: 60000; running: true; repeat: true; onTriggered: root.readColour() }
    Component.onCompleted: readColour()
}
