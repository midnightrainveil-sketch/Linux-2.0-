pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Hyprland

// The panel's refresh rate (archive-refresh): 60, 120 or "auto", which is
// 120 Hz plugged in and 60 Hz on battery. Hyprland sets the rate when it
// reads its config (hypr/archive/machine.lua); on Auto this tells it again
// when the charger is plugged in or pulled out.
Singleton {
    id: root

    readonly property var choices: ["60", "120", "auto"]
    readonly property string choice: {
        const s = file.text().trim();
        return choices.indexOf(s) >= 0 ? s : "120";
    }
    readonly property bool plugged: !UPower.onBattery
    readonly property int rate: choice === "auto" ? (plugged ? 120 : 60) : Number(choice)
    // what the laptop's panel really runs at (Hyprland's word for it), so
    // the bar never shows a rate the screen is not at
    property int actual: 0
    readonly property int shown: actual > 0 ? actual : rate

    function readActual(): void {
        if (!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")) return;
        Hyprland.refreshMonitors();
        settle.restart();
    }
    Timer {
        id: settle
        interval: 400
        onTriggered: {
            const panel = Hyprland.monitors.values.find(m => m.name.startsWith("eDP"));
            const r = panel?.lastIpcObject?.refreshRate ?? 0;
            root.actual = Math.round(r);
        }
    }
    // the panel set again: by archive-refresh (it reads the rate back), a
    // reload, or a screen plugged in
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded" || event.name.startsWith("monitor")) root.readActual();
        }
    }
    Component.onCompleted: readActual()

    function set(c: string): void { run(c); }
    function toggle(): void { run("toggle"); }
    function run(arg: string): void {
        Quickshell.execDetached(["archive-refresh", arg]);
        reread.restart();
        // (it takes a moment, and may try more than once)
        after.restart();
    }
    Timer { id: after; interval: 1600; onTriggered: { root.readActual(); late.restart(); } }
    Timer { id: late; interval: 2600; onTriggered: root.readActual() }

    onPluggedChanged: if (choice === "auto") run("apply")

    FileView {
        id: file
        path: Settings.stateHome + "/archive/refresh"
        watchChanges: true
        onFileChanged: reload()
        printErrors: false
    }
    Timer { id: reread; interval: 400; onTriggered: file.reload() }
}
