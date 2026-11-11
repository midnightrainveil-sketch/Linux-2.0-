pragma Singleton

import QtQuick
import Quickshell

// This theme's own wording and small choices, in one place. (Each theme is a
// folder of its own with its own copy of the shell: nothing here is read
// from, or shared with, another theme.)
Singleton {
    readonly property string theme: "night-service"
    readonly property bool ready: true
    readonly property var words: ({
        "archiveName": "COMPARTMENT 19",
        "timeSubtitle": "Timetable, Vienna – Venice.",
        "weatherTitle": "Conditions en Route",
        "audioTitle": "Carriage Recordings",
        "lockTitle": "Sleeping Car",
        "lockSubtitle": "Boarding by signature."
    })
    function word(key: string, fallback: string): string {
        const v = words[key];
        return typeof v === "string" && v !== "" ? v : fallback;
    }
    readonly property string plate: "0101-night-service"       // "" : the day's plate (services/Plates.qml)
    readonly property string barIcon: "train"
    readonly property url clockArt: Qt.resolvedUrl("../assets/flavours/night-service/clock-art.png")
}
