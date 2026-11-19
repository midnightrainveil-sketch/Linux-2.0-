pragma Singleton

import QtQuick
import Quickshell

// Which cartridge each app gets (assets/cartridges, made by
// tools/make_cartridges.py from art/Cartridges.png).
//
// Six apps have an illustrated label of their own: the browser, the
// terminal, the files, the settings, the music player and the images. Any
// other app gets a blank label, in one of the three colours (charcoal, cream,
// sage: always the same one for the same app), with its own icon set into it.
//
//   of(entry)        { art, icon, colour } for a desktop entry
//   ofClass(cls)     the same for a window's class (the taskbar's port)
//
// And the cartridge's way from the launcher to the taskbar's port:
//   eject(entry, x, y, s, top)   the launcher lowers one: its middle at x, y on
//                           the screen, drawn at scale s, the lifter's rods
//                           from y top (modules/Flight.qml lowers it into the port)
//   portX, portY, portS     where one stands in the port (the taskbar sets
//                           them): its middle x, the y of its foot, its scale
//   lastLaunched            what last went in; landed() when it has
Singleton {
    id: root

    property var lastLaunched: null
    property bool flying: false
    property var flyEntry: null
    property real fromX: 0
    property real fromY: 0
    property real fromS: 1
    property real liftTop: 0
    property real portX: 0
    property real portY: 0
    property real portS: 0.25
    signal landed()
    function eject(entry: var, x: real, y: real, s: real, top: real): void {
        flyEntry = entry; fromX = x; fromY = y; fromS = s; liftTop = top;
        flying = true;
    }
    function land(): void {
        lastLaunched = flyEntry;
        flying = false;
        landed();
    }

    // an illustrated label: what ids, classes or categories it covers
    readonly property var illustrated: [
        { art: "browser",  ids: ["firefox", "librewolf", "zen", "zen-browser", "app.zen_browser.zen", "chromium", "google-chrome", "brave-browser", "org.mozilla.firefox"], categories: ["WebBrowser"] },
        { art: "terminal", ids: ["kitty", "foot", "footclient", "alacritty", "org.wezfurlong.wezterm", "com.mitchellh.ghostty", "org.gnome.console", "retro-futurism.desk"], categories: ["TerminalEmulator"] },
        { art: "files",    ids: ["thunar", "org.gnome.nautilus", "nautilus", "pcmanfm", "org.kde.dolphin", "nemo"], categories: ["FileManager"] },
        { art: "settings", ids: ["org.gnome.settings", "gnome-control-center", "systemsettings", "nwg-look", "pavucontrol"], categories: ["Settings"] },
        { art: "music",    ids: ["spotify", "com.spotify.client", "rhythmbox", "org.gnome.music", "elisa", "strawberry", "audacious", "io.bassi.amberol"], categories: ["Music", "Audio"] },
        { art: "images",   ids: ["org.gnome.loupe", "eog", "org.gnome.eog", "imv", "feh", "gwenview", "org.kde.gwenview", "ristretto", "shotwell", "gthumb"], categories: ["Viewer", "Photography", "Graphics"] }
    ]
    readonly property var colours: ["charcoal", "cream", "sage"]

    function art(name: string): string { return Quickshell.shellPath("assets/cartridges/" + name + ".png"); }

    function norm(s: string): string { return (s ?? "").toLowerCase().replace(/\.desktop$/, ""); }
    function hash(s: string): int {
        let h = 7;
        for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) % 100003;
        return h;
    }

    function of(entry: var): var {
        if (!entry) return { art: art("blank-charcoal"), icon: "", colour: "charcoal" };
        const id = norm(entry.id), cats = entry.categories ?? [];
        const icon = entry.icon ? Quickshell.iconPath(entry.icon, true) : "";
        for (const l of illustrated)
            if (l.ids.indexOf(id) >= 0) return { art: art(l.art), icon: "", colour: "" };
        for (const l of illustrated)
            if (l.categories.some(c => cats.indexOf(c) >= 0)) return { art: art(l.art), icon: "", colour: "" };
        const colour = colours[hash(id || entry.name) % colours.length];
        return { art: art("blank-" + colour), icon: icon, colour: colour };
    }

    function ofClass(cls: string): var {
        if (!cls) return null;
        let entry = null;
        try { entry = DesktopEntries.heuristicLookup(cls); } catch (e) {}
        if (!entry) {
            const c = norm(cls);
            for (const l of illustrated)
                if (l.ids.indexOf(c) >= 0) return { art: art(l.art), icon: "", colour: "" };
            return { art: art("blank-" + colours[hash(c) % 3]), icon: Quickshell.iconPath(cls, true), colour: "" };
        }
        return of(entry);
    }
}
