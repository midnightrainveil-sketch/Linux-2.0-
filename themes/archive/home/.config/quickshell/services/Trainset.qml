pragma Singleton

import QtQuick
import Quickshell

// The little night train along the bar (modules/train/TrainRun.qml).
// `on`: trains keep setting off, one after another. Turned off, none sets
// off any more, and the one under way finishes its run (`running` stays
// true until it has left the screen).
Singleton {
    id: root
    property bool on: false
    property bool running: false
    function toggle(): void {
        on = !on;
        if (on) running = true;
    }
}
