pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Small helpers around Hyprland IPC. Hyprland 0.55+ is configured in Lua,
// and its dispatchers then take Lua expressions instead of the old strings.
Singleton {
    id: root

    function workspace(id: int): void {
        if (Hyprland.usingLua)
            Hyprland.dispatch(`hl.dsp.focus({ workspace = "${id}" })`);
        else
            Hyprland.dispatch("workspace " + id);
    }

    function relativeWorkspace(delta: int): void {
        const spec = (delta > 0 ? "e+" : "e-") + Math.abs(delta);
        if (Hyprland.usingLua)
            Hyprland.dispatch(`hl.dsp.focus({ workspace = "${spec}" })`);
        else
            Hyprland.dispatch("workspace " + spec);
    }

    // ---- breadcrumb for the bar: "/ home / atlas /"
    readonly property var active: Hyprland.activeToplevel
    readonly property string activeTitle: active?.title ?? ""
    readonly property string activeClass: (active?.lastIpcObject?.class ?? active?.wayland?.appId ?? "").toLowerCase()

    readonly property var crumbs: {
        const home = Settings.home;
        const title = root.activeTitle;
        // Shells set titles like "atlas@linden: ~/projects/rice".
        const m = title.match(/^[^@\s]+@[^:\s]+:\s*(.+)$/);
        let path = m ? m[1].trim() : "";
        if (path === "" && title.startsWith("/")) path = title;
        if (path === "" && title.startsWith("~")) path = title;
        if (path !== "") {
            if (path.startsWith("~")) path = home + path.slice(1);
            return path.split("/").filter(s => s.length > 0);
        }
        if (title !== "") {
            const cls = root.activeClass.split(".").pop();
            let t = title.length > 48 ? title.slice(0, 47) + "…" : title;
            return cls && cls !== t.toLowerCase() ? [cls, t.toLowerCase()] : [t.toLowerCase()];
        }
        return home.split("/").filter(s => s.length > 0);
    }

    // Workspace numbers flagged urgent, for the stamp mark in the bar.
    readonly property var urgent: Hyprland.workspaces.values.filter(w => w.urgent).map(w => w.id)

    // Keep occupancy info fresh: window open/close events don't always refresh it.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const n = event.name;
            if (n === "openwindow" || n === "closewindow" || n === "movewindow" || n === "movewindowv2")
                Hyprland.refreshWorkspaces();
        }
    }
}
