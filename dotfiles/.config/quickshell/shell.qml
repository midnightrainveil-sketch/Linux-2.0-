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
import qs.modules.windows
import qs.modules.quicksettings
import qs.modules.power
import qs.modules.notifications
import qs.modules.osd
import qs.modules.lock
import qs.modules.photo
import qs.modules.phonograph
import qs.modules.notebook
import qs.modules.typewriter

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
    LedgerYear  { screen: shell.focusedScreen }
    InstrumentCard { screen: shell.focusedScreen }
    Disposition { screen: shell.focusedScreen }
    Register    { id: registerCard; screen: shell.focusedScreen }
    Instrument  { screen: shell.focusedScreen }
    Correspondence { screen: shell.focusedScreen }
    Photograph  { id: photograph; screen: shell.focusedScreen }
    Phonograph  { screen: shell.focusedScreen }
    Notebook    { screen: shell.focusedScreen }
    Typewriter  { screen: shell.focusedScreen }
    PowerHold   { id: powerHold; screen: shell.focusedScreen }

    ReadingRoom { id: readingRoom }

    // ---- IPC, used by Hyprland binds, hypridle and scripts
    IpcHandler {
        target: "shell"
        function catalogue(): void { Panels.toggle("catalogue"); }
        function ledger(): void { Panels.toggle("ledger"); }
        function ledgerYear(): void { Panels.toggle("ledger-year"); }
        function instruments(): void { Panels.toggle("instrument"); }
        function disposition(): void { Panels.toggle("disposition"); }
        function phonograph(): void { Panels.toggle("phonograph"); }
        function notebook(): void { Panels.toggle("notebook"); }
        function typewriter(): void { Panels.toggle("typewriter"); }
        function close(): void { Panels.close(); }
        // the Register (open windows): the bar button, and Alt+Tab
        function register(): void { registerCard.toggle(); }
        function registerNext(): void { registerCard.step(1); }
        function registerPrev(): void { registerCard.step(-1); }
        function registerPick(): void { registerCard.commit(); }
    }

    // archive-screenshot: develop the shot as a print on the desk
    IpcHandler {
        target: "photo"
        // not "show": `qs ipc show` is a command of its own
        function develop(file: string): void { photograph.show(file); }
        function clear(): void { photograph.clear(); }
    }

    // the desk lamp (night), Super+Alt+L
    IpcHandler {
        target: "lamp"
        function toggle(): void { Lamp.toggle(); }
        function light(): void { Lamp.set(true); }
        function dark(): void { Lamp.set(false); }
    }

    // archive-desk: lay the record cards back in their places
    IpcHandler {
        target: "desk"
        function restore(): void { Desk.restore(); }
        function covered(on: bool): void { Desk.covered = on; }
    }

    // the power button, from binds.lua (which keeps the time)
    IpcHandler {
        target: "powerkey"
        function fill(ms: int): void { powerHold.show(ms); }
        function cancel(): void { powerHold.cancel(); }
        function close(): void { powerHold.close(); }
        function quick(): void { powerHold.cancel(); Panels.powerKey(); }
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
        function dnd(): void { Notifs.toggleDnd(); }
    }

    IpcHandler {
        target: "media"
        function toggle(): void { Media.toggle(); }
        function next(): void { Media.next(); }
        function previous(): void { Media.previous(); }
    }
}
