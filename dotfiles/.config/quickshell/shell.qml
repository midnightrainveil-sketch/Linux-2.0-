//@ pragma AppId archive.shell

// The Archive shell. Hyprland handles windows; this draws everything else:
// the plate (wallpaper), the record column, the footer bar, the popup cards,
// notifications, the volume / brightness reading and the lock screen.
//
//   Run:      qs            (Hyprland starts it, see hyprland.lua)
//   Reload:   saves reload automatically; or `qs kill && qs -d`
//   IPC:      qs ipc show

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.services
import qs.modules.background
import qs.modules.records
import qs.modules.bar
import qs.modules.launcher
import qs.modules.calendar
import qs.modules.quicksettings
import qs.modules.power
import qs.modules.notifications
import qs.modules.osd
import qs.modules.lock

ShellRoot {
    id: shell

    readonly property var focusedScreen:
        Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

    // ---- per screen: the sheet, the records and the footer strip
    Variants {
        model: Quickshell.screens
        Scope {
            id: perScreen
            required property var modelData
            Plate { modelData: perScreen.modelData }
            Records { modelData: perScreen.modelData }
            LetterTray { screen: perScreen.modelData }
            Bar { modelData: perScreen.modelData }
        }
    }

    // ---- one at a time, on the focused screen
    Catalogue   { screen: shell.focusedScreen }
    Ledger      { screen: shell.focusedScreen }
    InstrumentCard { screen: shell.focusedScreen }
    Disposition { screen: shell.focusedScreen }
    Instrument  { screen: shell.focusedScreen }
    Correspondence { screen: shell.focusedScreen }

    ReadingRoom { id: readingRoom }

    // ---- IPC, used by Hyprland binds, hypridle and scripts
    IpcHandler {
        target: "shell"
        function catalogue(): void { Panels.toggle("catalogue"); }
        function ledger(): void { Panels.toggle("ledger"); }
        function instruments(): void { Panels.toggle("instrument"); }
        function disposition(): void { Panels.toggle("disposition"); }
        function close(): void { Panels.close(); }
    }

    // archive-desk: lay the record cards back in their places
    IpcHandler {
        target: "desk"
        function restore(): void { Desk.restore(); }
    }

    IpcHandler {
        target: "lock"
        function lock(): void { readingRoom.lock(); }
    }

    IpcHandler {
        target: "brightness"
        function up(): void { Brightness.step(5); }
        function down(): void { Brightness.step(-5); }
        function set(percent: int): void { Brightness.set(percent); }
    }

    IpcHandler {
        target: "osd"
        function volume(): void { Panels.osd("volume"); }
        function brightness(): void { Brightness.refresh(); Panels.osd("brightness"); }
    }

    IpcHandler {
        target: "sound"
        function play(event: string): void { Sounds.play(event); }
    }

    IpcHandler {
        target: "notifications"
        function clear(): void { Notifs.clearAll(); }
        function dnd(): void { Notifs.dnd = !Notifs.dnd; }
    }

    IpcHandler {
        target: "media"
        function toggle(): void { Media.toggle(); }
        function next(): void { Media.next(); }
        function previous(): void { Media.previous(); }
    }
}
