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

    // ---- the desk's windows. All of them are built afresh whenever a screen
    // comes or goes (a lid, sleep, a cable) and after every unlock: the
    // shell can be restarted while the screen is away (it stops when its
    // screen goes), and a window made for a screen that has gone, or whose
    // surface the compositor closed with it, would never show again.
    // (the picture only when a screen comes or goes: rebuilt on every unlock,
    // its city would start round again)
    property bool deskAlive: true
    property bool pictureAlive: true
    property bool screensChanged: false
    function renewDesk(screens: bool): void { if (screens) screensChanged = true; settle.restart(); }
    Timer {
        id: settle; interval: 400
        onTriggered: { shell.deskAlive = false; if (shell.screensChanged) shell.pictureAlive = false; rebuild.restart(); }
    }
    Timer { id: rebuild; interval: 60; onTriggered: { shell.deskAlive = true; shell.pictureAlive = true; shell.screensChanged = false; } }
    Connections { target: Scene; function onUnlocked() { shell.renewDesk(false); } }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const n = event.name;
            if (n === "monitoradded" || n === "monitoraddedv2" || n === "monitorremoved" || n === "monitorremovedv2")
                shell.renewDesk(true);
        }
    }

    Variants {
        model: Quickshell.screens
        Scope {
            id: perScreen
            required property var modelData
            LazyLoader { active: shell.pictureAlive; Backdrop { modelData: perScreen.modelData } }
            LazyLoader { active: shell.deskAlive; Taskbar { modelData: perScreen.modelData } }
        }
    }

    LazyLoader { active: shell.deskAlive; Mail { screen: shell.focusedScreen } }

    // built only while open
    LazyLoader { active: Panels.open === "themes"; ThemesSheet { screen: shell.focusedScreen } }

    // the widgets (widgets/index.json), on the screen in use: in the middle
    // over the blurred desk, or over the taskbar's right end
    LazyLoader { active: shell.deskAlive; WidgetStage { screen: shell.focusedScreen } }
    LazyLoader { active: shell.deskAlive; WidgetStage { screen: shell.focusedScreen; taskbar: true } }
    // the launcher's lifter, over the taskbar while it lowers a cartridge in
    LazyLoader { active: shell.deskAlive; Lifter { screen: shell.focusedScreen } }

    // ULTRA_CHECK=1: compile and make every widget once, and say how it went
    LazyLoader { active: Quickshell.env("ULTRA_CHECK") === "1"; SelfCheck {} }

    Lock { id: lockScreen }
    Connections { target: Scene; function onLockNow() { lockScreen.lock(); } }

    // ---- IPC, used by Hyprland's binds, the idle timer and scripts
    IpcHandler {
        target: "shell"
        function launcher(): void { Widgets.toggle("launcher"); }
        // (the power button: the power widget; locked, the lock screen's
        // device turns to its power face instead, nothing done at once)
        function power(): void { if (Scene.locked) lockScreen.showPower(1); else Widgets.toggle("power"); }
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
