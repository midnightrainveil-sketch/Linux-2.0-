pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// User settings from ~/.config/archive/settings.json. Every value has a
// default, so a missing or broken file never breaks the shell.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (home + "/.config")
    readonly property string stateHome:  Quickshell.env("XDG_STATE_HOME")  || (home + "/.local/state")
    readonly property string dataHome:   Quickshell.env("XDG_DATA_HOME")   || (home + "/.local/share")

    readonly property string user: Quickshell.env("USER") || "atlas"

    property var data: ({})

    function get(path: string, fallback: var): var {
        let v = root.data;
        for (const k of path.split(".")) {
            if (v === undefined || v === null || typeof v !== "object" || !(k in v)) return fallback;
            v = v[k];
        }
        return v;
    }

    readonly property string archiveName:   get("archive.name", "ROYAL BOTANIC ARCHIVE")
    readonly property string archiveStamp:  get("archive.stamp", "REG. BOT. ARCHIVUM")
    readonly property string placeName:     get("location.name", "Singapore")
    readonly property string placeCountry:  get("location.country", "Singapore")
    readonly property real   latitude:      get("location.latitude", 1.3521)
    readonly property real   longitude:     get("location.longitude", 103.8198)
    readonly property int    minWorkspaces: get("bar.minWorkspaces", 4)
    readonly property bool   showTime:      get("records.time", true)
    readonly property bool   showWeather:   get("records.weather", true)
    readonly property bool   showAudio:     get("records.audio", true)
    readonly property bool   reducedMotion: get("reducedMotion", false)
    readonly property bool   sounds:        get("sounds", true)
    readonly property string fixedPlate:    get("plate", "")
    readonly property bool   doNotDisturb:  get("doNotDisturb", false)
    readonly property string terminal:      get("terminal", "foot")

    FileView {
        id: file
        path: root.configHome + "/archive/settings.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.data = JSON.parse(file.text());
            } catch (e) {
                console.warn("archive: settings.json is not valid JSON:", e);
            }
        }
    }
}
