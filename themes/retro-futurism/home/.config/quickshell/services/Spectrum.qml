pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The music's levels, for the cassette players' meters: six bands, 0..1
// each, from cava (cava.conf here) while something plays. Without cava,
// a lively stand-in, so the meters still move with the music.
Singleton {
    id: root

    readonly property bool on: Media.playing
    property var levels: [0, 0, 0, 0, 0, 0]
    property bool real: false               // cava is answering

    Process {
        id: cava
        command: ["cava", "-p", Quickshell.shellPath("cava.conf")]
        running: root.on
        stdout: SplitParser {
            onRead: line => {
                const v = line.split(";").filter(s => s !== "").map(s => Math.min(1, parseInt(s) / 100));
                if (v.length >= 6) { root.real = true; root.levels = v.slice(0, 6); }
            }
        }
        onRunningChanged: if (!running) { root.real = false; if (!root.on) root.levels = [0, 0, 0, 0, 0, 0]; }
    }

    // the stand-in: each band wanders to a new height several times a
    // second, the low ones fuller, all of them together on a beat
    property real phase: 0
    Timer {
        interval: 90
        repeat: true
        running: root.on && !root.real
        onTriggered: {
            root.phase += 0.09;
            const beat = Math.pow(Math.max(0, Math.sin(root.phase * 2 * Math.PI * 1.9)), 6);
            const v = [];
            for (let i = 0; i < 6; i++) {
                const body = 0.62 - i * 0.07;
                v.push(Math.max(0.05, Math.min(1, body * (0.55 + 0.6 * Math.random()) + 0.3 * beat)));
            }
            root.levels = v;
        }
    }
    onOnChanged: if (!on) levels = [0, 0, 0, 0, 0, 0]
}
