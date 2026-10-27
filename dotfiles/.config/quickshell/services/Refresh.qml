pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

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

    function set(c: string): void { run(c); }
    function toggle(): void { run("toggle"); }
    function run(arg: string): void {
        Quickshell.execDetached(["archive-refresh", arg]);
        reread.restart();
    }

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
