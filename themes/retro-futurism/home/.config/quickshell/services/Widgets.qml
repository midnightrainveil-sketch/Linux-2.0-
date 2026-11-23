pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The widgets: which there are (widgets/index.json) and which one is up.
// One at a time; the stage (modules/WidgetStage.qml) shows it.
//
//   Widgets.open("typewriter")      bring it up (from Hyprland:
//   Widgets.toggle("typewriter")      qs ipc call widget toggle typewriter)
//   Widgets.close()                  put it away
//
// A widget's own state is kept in ~/.local/state/ultra/retro-futurism/
// widgets/<id>.json (components/WidgetStore.qml).
Singleton {
    id: root

    property var list: []                   // the index's entries
    property string current: ""             // the widget up, or ""
    property string last: ""                // the one before (for a quick return)

    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state"))
        + "/ultra/retro-futurism/widgets"

    function find(id: string): var { return list.find(w => w.id === id) ?? null; }
    function source(id: string): string { return Quickshell.shellPath("widgets/" + id + "/Main.qml"); }
    // where it comes up: "center" (blurred behind) or "taskbar" (over its right end)
    function placement(id: string): string { return find(id)?.placement ?? "center"; }

    function open(id: string): void {
        const w = find(id);
        if (!w) { console.warn("widgets: no widget", id); return; }
        Panels.close();                     // one thing over the desk at a time
        if (current !== "" && current !== id) last = current;
        current = id;
    }
    // for the shell itself (a notification for the pager): even if not callable
    function show(id: string): void { if (find(id)) { Panels.close(); current = id; } }
    function close(): void { if (current !== "") { last = current; current = ""; } }
    function toggle(id: string): void {
        if (current === id) { close(); return; }
        const w = find(id);
        if (w && w.callable === false) { console.warn("widgets:", id, "is not called by hand"); return; }
        open(id);
    }

    // a swipe to another page (workspace), or any change of page: the widget
    // is put away (what it set going, the music, goes on)
    Connections {
        target: Hypr
        function onActiveIdChanged() { root.close(); }
    }

    FileView {
        path: Quickshell.shellPath("widgets/index.json")
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { root.list = JSON.parse(text()).widgets ?? []; }
            catch (e) { console.warn("widgets: index.json is not valid JSON:", e); }
        }
    }

    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", root.stateDir])
}
