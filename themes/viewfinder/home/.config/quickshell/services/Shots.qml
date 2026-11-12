pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The frame counter: how many pictures are on the roll (screenshots in
// ~/Pictures/Viewfinder; a roll holds 36, then a new one begins).
Singleton {
    id: root
    property int total: 0
    readonly property int frame: total % 36
    function refresh(): void { counter.running = true; }
    function take(kind: string): void { Quickshell.execDetached(["ultra-screenshot", kind]); }

    Process {
        id: counter
        command: ["ultra-screenshot", "count"]
        stdout: StdioCollector { onStreamFinished: root.total = parseInt(text.trim()) || 0 }
    }
    Component.onCompleted: refresh()
}
