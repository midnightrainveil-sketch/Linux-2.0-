pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The theme this session was logged in to, when it is a variant of the
// Archive (theme.json "base": "archive"): the same desk, with its own sheet,
// wording and small pictures (theme.json "flavour"). The choice is read as
// the session starts (archive-theme; Hyprland's mark for this session) and
// kept for it. Every word or picture not given keeps the Archive's own.
//
//   "flavour": {
//     "plate":        "0101-night-service"   the wallpaper sheet (plates/<id>)
//     "archiveName":  "NIGHT SERVICE"        the clock card's (and lock's) heading
//     "timeSubtitle": "Timetable."
//     "weatherTitle": "Conditions en Route"
//     "audioTitle":   "Carriage Recordings"
//     "lockTitle":    "Sleeping Car"          "lockSubtitle": "Boarding by signature."
//     "barIcon":      "lantern"              (assets/icons/<name>.svg)
//     "clockArt":     "clock-art.png"        (assets/flavours/<id>/, kept in colour)
//     "specimen":     false                  the month's pressed specimen on the desk
//     "icons":        "suitcase"             folders as suitcases (archive-icons, at log-in)
//     "player":       "musicbox"             the audio card's player (else the cassette)
//     "keepsakes":    true                   the postcard and label on the desk (Keepsakes.qml)
//   }
Singleton {
    id: root

    readonly property string sig: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || ""
    readonly property string runtime: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    property string theme: "archive"
    property var f: ({})
    property bool fromMark: false
    // known: which theme, and (for a variant) what it changes. Until then the
    // sheet waits, so a variant's session never loads the Archive's first.
    property bool resolved: false
    property bool manifestDone: false
    readonly property bool ready: resolved && (theme === "archive" || manifestDone)
    Timer { interval: 1500; running: !root.ready; onTriggered: { root.resolved = true; root.manifestDone = true; } }

    function word(key: string, fallback: string): string {
        const v = f[key];
        return typeof v === "string" && v !== "" ? v : fallback;
    }
    readonly property string plate: word("plate", "")
    readonly property string barIcon: word("barIcon", "seedling")
    readonly property url clockArt: f.clockArt ? Qt.resolvedUrl("../assets/flavours/" + theme + "/" + f.clockArt) : ""
    readonly property bool specimen: f.specimen !== false
    readonly property bool keepsakes: f.keepsakes === true
    readonly property string player: word("player", "cassette")

    // this session's theme: Hyprland's mark for it, else the one chosen
    FileView {
        id: mark
        path: root.sig !== "" ? root.runtime + "/archive-theme-" + root.sig : ""
        printErrors: false
        onLoaded: { root.fromMark = true; root.useTheme(text()); }
    }
    FileView {
        id: chosen
        path: Settings.configHome + "/archive/theme"
        printErrors: false
        onLoaded: if (!root.fromMark) root.useTheme(text())
        onLoadFailed: if (!root.fromMark) root.useTheme("archive")
    }
    function useTheme(t: string): void {
        const id = (t || "").trim().replace(/[^A-Za-z0-9_-]/g, "") || "archive";
        theme = id;
        resolved = true;
    }
    FileView {
        id: manifest
        path: root.theme === "archive" ? "" : Settings.dataHome + "/archive/themes/" + root.theme + "/theme.json"
        printErrors: false
        onLoaded: {
            try {
                const j = JSON.parse(text());
                root.f = j.base === "archive" && j.flavour ? j.flavour : {};
            } catch (e) { root.f = {}; }
            root.manifestDone = true;
        }
        onLoadFailed: root.manifestDone = true
    }
}
