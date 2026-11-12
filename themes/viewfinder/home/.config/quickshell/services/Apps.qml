pragma Singleton

import QtQuick
import Quickshell

// The installed programs, and a plain word for a window's class.
Singleton {
    id: root

    readonly property var all: DesktopEntries.applications.values
        .filter(a => !a.noDisplay)
        .slice()
        .sort((a, b) => a.name.localeCompare(b.name))

    readonly property var words: ({
        "foot": "Terminal", "footclient": "Terminal", "viewfinder.desk": "Terminal", "kitty": "Terminal",
        "alacritty": "Terminal", "com.mitchellh.ghostty": "Terminal", "org.wezfurlong.wezterm": "Terminal",
        "org.gnome.nautilus": "Files", "thunar": "Files", "pcmanfm": "Files",
        "code": "Editor", "code-oss": "Editor", "codium": "Editor"
    })

    function label(cls: string): string {
        const key = cls.toLowerCase();
        if (words[key]) return words[key];
        let entry = null;
        try { entry = DesktopEntries.heuristicLookup ? DesktopEntries.heuristicLookup(cls) : DesktopEntries.byId(cls); } catch (e) {}
        if (entry && entry.name) return entry.name;
        return cls.split(".").pop() || "Window";
    }

    function search(query: string): var {
        const q = query.trim().toLowerCase();
        if (q === "") return all;
        const scored = [];
        for (const a of all) {
            const n = a.name.toLowerCase();
            const extra = [a.genericName ?? "", (a.keywords ?? []).join(" "), (a.categories ?? []).join(" "), a.id ?? ""].join(" ").toLowerCase();
            let s = 0;
            if (n.startsWith(q)) s = 100;
            else if (n.split(/\s+/).some(w => w.startsWith(q))) s = 80;
            else if (n.includes(q)) s = 60;
            else if (extra.includes(q)) s = 30;
            if (s > 0) scored.push({ a, s });
        }
        scored.sort((x, y) => y.s - x.s || x.a.name.localeCompare(y.a.name));
        return scored.map(x => x.a);
    }

    function launch(app: var): void {
        if (!app) return;
        if (app.runInTerminal)
            Quickshell.execDetached({ command: [Settings.terminal, "-e"].concat(app.command), workingDirectory: app.workingDirectory });
        else
            app.execute();
    }
}
