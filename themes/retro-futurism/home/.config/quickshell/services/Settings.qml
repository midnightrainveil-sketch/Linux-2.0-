pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// ~/.config/ultra/retro-futurism/settings.json. Every value has a default, so a
// missing or broken file never breaks the shell.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (home + "/.config")
    readonly property string dataHome: Quickshell.env("XDG_DATA_HOME") || (home + "/.local/share")
    readonly property string own: configHome + "/ultra/retro-futurism"
    readonly property string art: dataHome + "/ultra/retro-futurism"
    readonly property string user: Quickshell.env("USER") || "user"

    property var values: ({})
    function get(key: string, fallback: var): var {
        const v = root.values[key];
        return v === undefined || v === null ? fallback : v;
    }

    readonly property real latitude: get("latitude", 1.3521)
    readonly property real longitude: get("longitude", 103.8198)
    readonly property int workspaces: get("workspaces", 6)
    readonly property string terminal: get("terminal", "foot")
    readonly property string search: get("search", "https://www.google.com/search?q=%s")
    // a picture of your own instead of the theme's: ~/.config/ultra/retro-futurism/wallpaper.jpg
    readonly property string wallpaper: get("wallpaper", "")
    // the city outside the train's window: seconds for the view to come
    // round once (0 holds it still)
    readonly property int windowSeconds: get("windowSeconds", 55)
    // the car's gentle sway, and the jolt of a rail joint now and then
    readonly property bool sway: get("sway", true)
    readonly property bool bumps: get("bumps", true)

    FileView {
        id: file
        path: root.own + "/settings.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try { root.values = JSON.parse(file.text()); }
            catch (e) { console.warn("retro-futurism: settings.json is not valid JSON:", e); }
        }
    }
}
