pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// ~/.config/ultra/viewfinder/settings.json. Every value has a default, so a
// missing or broken file never breaks the shell.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (home + "/.config")
    readonly property string dataHome: Quickshell.env("XDG_DATA_HOME") || (home + "/.local/share")
    readonly property string own: configHome + "/ultra/viewfinder"
    readonly property string art: dataHome + "/ultra/viewfinder"
    readonly property string user: Quickshell.env("USER") || "user"

    property var data: ({})
    function get(key: string, fallback: var): var {
        const v = root.data[key];
        return v === undefined || v === null ? fallback : v;
    }

    readonly property real latitude: get("latitude", 1.3521)
    readonly property real longitude: get("longitude", 103.8198)
    readonly property int workspaces: get("workspaces", 5)
    readonly property string terminal: get("terminal", "foot")
    readonly property string search: get("search", "https://www.google.com/search?q=%s")
    // a picture of your own instead of the theme's: ~/.config/ultra/viewfinder/wallpaper.jpg
    readonly property string wallpaper: get("wallpaper", "")

    FileView {
        id: file
        path: root.own + "/settings.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try { root.data = JSON.parse(file.text()); }
            catch (e) { console.warn("viewfinder: settings.json is not valid JSON:", e); }
        }
    }
}
