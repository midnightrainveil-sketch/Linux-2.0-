//@ pragma AppId viewfinder.shell

// The Viewfinder shell. Hyprland handles windows; this draws the rest: the
// picture and the marks on it, the two bars, the film strip (workspaces),
// now playing and the notes, notifications, the launcher, the power menu,
// the themes and the lock screen.
//
//   Run:      qs            (Hyprland starts it, see hypr/theme.lua)
//   IPC:      qs ipc show

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.services
import qs.modules

ShellRoot {
    id: shell

    readonly property var focusedScreen:
        Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]

    Variants {
        model: Quickshell.screens
        Scope {
            id: perScreen
            required property var modelData
            Backdrop { modelData: perScreen.modelData }
            TopBar { modelData: perScreen.modelData }
            BottomBar { modelData: perScreen.modelData }
            FilmStrip { modelData: perScreen.modelData }
        }
    }

    Mail { screen: shell.focusedScreen }

    // built only while open
    LazyLoader { active: Panels.open === "launcher"; Launcher { screen: shell.focusedScreen } }
    LazyLoader { active: Panels.open === "power"; PowerMenu { screen: shell.focusedScreen } }
    LazyLoader { active: Panels.open === "themes"; ThemesSheet { screen: shell.focusedScreen } }

    Lock { id: lockScreen }

    // ---- IPC, used by Hyprland's binds, the idle timer and scripts
    IpcHandler {
        target: "shell"
        function launcher(): void { Panels.toggle("launcher"); }
        function power(): void { Panels.toggle("power"); }
        function themes(): void { Panels.toggle("themes"); }
        function close(): void { Panels.close(); }
    }
    IpcHandler {
        target: "lock"
        function lock(): void { lockScreen.lock(); }
    }
    IpcHandler {
        target: "brightness"
        function up(): void { Brightness.step(5); }
        function down(): void { Brightness.step(-5); }
        function set(percent: int): void { Brightness.set(percent); }
    }
    IpcHandler {
        target: "osd"
        function volume(): void {}
        function brightness(): void { Brightness.refresh(); }
    }
    IpcHandler {
        target: "shots"
        function refresh(): void { Shots.refresh(); }
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
