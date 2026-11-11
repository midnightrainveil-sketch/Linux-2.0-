pragma Singleton

import QtQuick
import Quickshell

// This theme's own wording and small choices, in one place. (Each theme is a
// folder of its own with its own copy of the shell: nothing here is read
// from, or shared with, another theme.)
Singleton {
    readonly property string theme: "archive"
    readonly property bool ready: true
    readonly property var words: ({})
    function word(key: string, fallback: string): string {
        const v = words[key];
        return typeof v === "string" && v !== "" ? v : fallback;
    }
    readonly property string plate: ""       // "" : the day's plate (services/Plates.qml)
    readonly property string barIcon: "seedling"
    readonly property url clockArt: ""
}
