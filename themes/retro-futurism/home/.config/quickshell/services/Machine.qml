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
//   gpu           the graphics mode: "hybrid", "integrated", "ultimate", or
//                 "none" (no switches on this kernel)   (ultra-gpu)
Singleton {
    id: root

    readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")

    // ---- refresh rate
    property string refresh: "auto"
    function setRefresh(v: string): void {
        refresh = v;                                    // at once; the file follows
        Quickshell.execDetached(["ultra-refresh", v]);
        hzSoon.restart();
    }
    // the rate the screen in use is running at now, in Hz (0: not known yet)
    property int hz: 0
    function readHz(): void { if (!hzReader.running) hzReader.running = true; }
    Process {
        id: hzReader
        command: ["sh", "-c", "hyprctl monitors -j 2>/dev/null | jq -r '[.[] | select(.focused)][0].refreshRate // empty'"]
        stdout: StdioCollector { onStreamFinished: { const v = parseFloat(text); if (!isNaN(v) && v > 0) root.hz = Math.round(v); } }
    }
    Timer { id: hzSoon; interval: 1500; onTriggered: root.readHz() }
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
    // (HDR, when on, takes the panel's colour over: ultra-hdr)
    property bool hdr: false
    readonly property string colourName: hdr ? "HDR"
        : colour === "none" || colour === "" ? "NONE" : colour.split("/").pop().replace(/\.(icc|icm)$/i, "")
    function readColour(): void { iccReader.running = true; hdrReader.running = true; }
    Process {
        id: iccReader
        command: ["ultra-icc", "current"]
        stdout: StdioCollector { onStreamFinished: root.colour = text.trim() || "none" }
    }
    Process {
        id: hdrReader
        command: ["sh", "-c", "cat \"${XDG_STATE_HOME:-$HOME/.local/state}/ultra/hdr\" 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: root.hdr = text.trim() === "on" }
    }
    Timer { interval: 60000; running: true; repeat: true; onTriggered: root.readColour() }

    // ---- graphics mode (a switch is finished by logging out and in)
    property string gpu: "none"
    function readGpu(): void { if (!gpuReader.running) gpuReader.running = true; }
    function toggleGpu(): void {
        Quickshell.execDetached(["ultra-gpu", "toggle"]);
        gpuSoon.restart();
    }
    Process {
        id: gpuReader
        command: ["ultra-gpu"]
        stdout: StdioCollector { onStreamFinished: { const v = text.trim(); if (v !== "") root.gpu = v; } }
    }
    Timer { id: gpuSoon; interval: 2500; onTriggered: root.readGpu() }

    Component.onCompleted: { readColour(); readGpu(); }
}
