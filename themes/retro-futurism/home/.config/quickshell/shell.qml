//@ pragma AppId retro-futurism.shell

// The Retro Futurism shell. Hyprland handles windows; this draws the rest: the
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
            Taskbar { modelData: perScreen.modelData }
        }
    }

    Mail { screen: shell.focusedScreen }

    // built only while open
    LazyLoader { active: Panels.open === "themes"; ThemesSheet { screen: shell.focusedScreen } }

    // the widgets (widgets/index.json), on the screen in use: in the middle
    // over the blurred desk, or over the taskbar's right end
    WidgetStage { screen: shell.focusedScreen }
    WidgetStage { screen: shell.focusedScreen; taskbar: true }

    Lock { id: lockScreen }
    Connections { target: Scene; function onLockNow() { lockScreen.lock(); } }

    // ---- IPC, used by Hyprland's binds, the idle timer and scripts
    IpcHandler {
        target: "shell"
        function launcher(): void { Widgets.toggle("launcher"); }
        function power(): void { Widgets.toggle("power"); }
        function themes(): void { Panels.toggle("themes"); }
        function close(): void { Panels.close(); Widgets.close(); }
    }
    // the widgets: qs ipc call widget toggle typewriter (open, close, list)
    IpcHandler {
        target: "widget"
        function toggle(id: string): void { Widgets.toggle(id); }
        function open(id: string): void { Widgets.open(id); }
        function close(): void { Widgets.close(); }
        function list(): string { return Widgets.list.map(w => w.id + (w.callable === false ? " (shell only)" : "") + "\t" + w.key).join("\n"); }
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
