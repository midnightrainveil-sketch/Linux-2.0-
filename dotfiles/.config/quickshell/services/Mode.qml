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

    // the look by day: "folio" (the default) or "original" (archive-mode
    // folio | original | night; the Instrument card's Sheet picker)
    readonly property string style: styleFile.text().trim() === "original" ? "original" : "folio"
    readonly property var looks: ["folio", "original", "night"]
    readonly property int look: isNight ? 2 : (style === "original" ? 1 : 0)
    function setLook(i: int): void { set(looks[i]); }
    function toggle(): void { set("toggle"); }

    // How far Folio goes from the original (0 to 1) and how dark the
    // wallpaper's vignette is (0 to 1): the Instrument card's sliders, kept in
    // state/archive/folio and state/archive/vignette. While a slider is
    // dragged the shell follows it at once; on letting go it is written down
    // and Hyprland reloads, so the windows' torn edges follow too.
    readonly property real folioSaved: number(folioFile, 0.5)
    readonly property real vignetteSaved: number(vignetteFile, 0.7)
    property real folioLive: -1
    property real vignetteLive: -1
    readonly property real folioAmount: folioLive >= 0 ? folioLive : folioSaved
    readonly property real vignette: vignetteLive >= 0 ? vignetteLive : vignetteSaved

    function number(f, fallback: real): real {
        const v = parseFloat(f.text().trim());
        return isNaN(v) ? fallback : Math.max(0, Math.min(1, v));
    }
    function dragFolio(v: real): void { folioLive = v; folioWrite.restart(); }
    function dragVignette(v: real): void { vignetteLive = v; vignetteWrite.restart(); }

    Timer {
        id: folioWrite
        interval: 450
        onTriggered: {
            folioFile.setText(root.folioLive.toFixed(2) + "\n");
            Quickshell.execDetached(["sh", "-c", "[ -n \"$HYPRLAND_INSTANCE_SIGNATURE\" ] && hyprctl reload >/dev/null 2>&1"]);
        }
    }
    Timer {
        id: vignetteWrite
        interval: 450
        onTriggered: vignetteFile.setText(root.vignetteLive.toFixed(2) + "\n")
    }

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
        id: styleFile
        path: Settings.stateHome + "/archive/style"
        watchChanges: true
        onFileChanged: reload()
    }

    FileView {
        id: folioFile
        path: Settings.stateHome + "/archive/folio"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        // once written down, the saved value is the one to follow
        onLoaded: if (Math.abs(root.folioSaved - root.folioLive) < 0.006) root.folioLive = -1
    }

    FileView {
        id: vignetteFile
        path: Settings.stateHome + "/archive/vignette"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: if (Math.abs(root.vignetteSaved - root.vignetteLive) < 0.006) root.vignetteLive = -1
    }

    FileView {
        id: grainFile
        path: Settings.stateHome + "/archive/grain"
        watchChanges: true
        onFileChanged: reload()
    }
}
