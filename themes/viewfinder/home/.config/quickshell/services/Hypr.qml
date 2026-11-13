pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Hyprland: workspaces, and where the windows of the workspace in view lie
// (for the captions under them and the focus marks round the one in use).
Singleton {
    id: root

    function workspace(id: int): void {
        if (Hyprland.usingLua) Hyprland.dispatch(`hl.dsp.focus({ workspace = "${id}" })`);
        else Hyprland.dispatch("workspace " + id);
    }
    function relativeWorkspace(delta: int): void {
        const spec = (delta > 0 ? "e+" : "e-") + Math.abs(delta);
        if (Hyprland.usingLua) Hyprland.dispatch(`hl.dsp.focus({ workspace = "${spec}" })`);
        else Hyprland.dispatch("workspace " + spec);
    }

    readonly property int activeId: Hyprland.focusedMonitor?.activeWorkspace?.id ?? 1
    readonly property var ids: {
        let top = Settings.workspaces;
        for (const w of Hyprland.workspaces.values)
            if (w.id > 0 && w.id <= 9) top = Math.max(top, w.id);
        const out = [];
        for (let i = 1; i <= top; i++) out.push(i);
        return out;
    }
    // plain values, read afresh on each change (no workspace object is kept)
    readonly property var state: {
        const out = {};
        for (const w of Hyprland.workspaces.values) {
            if (!w || w.id < 1 || w.id > 9) continue;
            out[w.id] = { occupied: (w.toplevels?.values?.length ?? 0) > 0, urgent: w.urgent === true };
        }
        return out;
    }

    readonly property string activeTitle: Hyprland.activeToplevel?.title ?? ""

    // ---- the windows in view: [{ key, x, y, w, h, cls, active }]
    property var windows: []
    property bool fullscreen: false

    function collect(): void {
        const ws = Hyprland.focusedMonitor?.activeWorkspace;
        const tops = ws?.toplevels?.values ?? [];
        const mon = Hyprland.focusedMonitor;
        const ox = mon?.x ?? 0, oy = mon?.y ?? 0;
        const act = Hyprland.activeToplevel;
        const out = [];
        let full = false;
        for (const t of tops) {
            const o = t?.lastIpcObject;
            if (!o || !o.at || !o.size) continue;
            if (o.hidden === true || o.mapped === false) continue;
            if ((o.fullscreen ?? 0) > 0) full = true;
            out.push({
                key: String(o.address ?? t.address ?? out.length),
                x: o.at[0] - ox, y: o.at[1] - oy, w: o.size[0], h: o.size[1],
                cls: String(o.class ?? ""),
                active: act !== null && act !== undefined && act === t
            });
        }
        out.sort((a, b) => a.y - b.y || a.x - b.x);
        fullscreen = full || (ws?.hasFullscreen ?? false);
        // only when something moved: nothing is drawn again for a look that
        // finds the windows where they were
        const mark = JSON.stringify(out);
        if (mark !== seen) { seen = mark; windows = out; }
    }
    property string seen: "[]"

    function look(): void { Hyprland.refreshToplevels(); soon.restart(); settled.restart(); }
    // once quickly, and once when the window has finished moving
    Timer { id: soon; interval: 90; onTriggered: root.collect() }
    Timer { id: settled; interval: 420; onTriggered: { Hyprland.refreshToplevels(); late.restart(); } }
    Timer { id: late; interval: 90; onTriggered: root.collect() }
    // a window dragged or resized by hand says nothing: look now and then
    // (not under a fullscreen window, where no caption shows)
    Timer { interval: 2500; running: root.windows.length > 0 && !root.fullscreen; repeat: true; onTriggered: root.look() }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const n = event.name;
            if (n === "openwindow" || n === "closewindow" || n === "movewindow" || n === "movewindowv2")
                Hyprland.refreshWorkspaces();
            if (n === "openwindow" || n === "closewindow" || n === "movewindow" || n === "movewindowv2"
                || n === "activewindowv2" || n === "workspace" || n === "workspacev2" || n === "focusedmon"
                || n === "changefloatingmode" || n === "fullscreen" || n === "activespecial")
                root.look();
        }
    }
    Component.onCompleted: look()
}
