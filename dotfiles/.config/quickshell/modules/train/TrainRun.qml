import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.theme
import qs.services

// A night train running along the top of the bar, left to right, above the
// windows: engine and tender, baggage van, two coaches, the dining car and
// the sleeping car (assets/train, tools/import_train.py), steam drifting
// back from the chimney. It never takes a click: everything goes through
// to what is under it.
PanelWindow {
    id: win

    anchors { left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "archive-train"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // (wheels on the bar's top rule)
    margins.bottom: Theme.barHeight - 3
    implicitHeight: 120
    color: "transparent"
    mask: Region {}

    readonly property real speed: 110          // px a second
    readonly property real gap: 1.6            // s between one train and the next
    property var spec: ({ vehicles: [], steam: [] })
    readonly property var cars: (spec.vehicles || []).slice().reverse()   // rear first, left to right
    readonly property real length: cars.reduce((s, v) => s + v.w - 1, 0)
    // the chimney, this far back from the engine's nose
    readonly property real chimneyBack: (cars.length ? cars[cars.length - 1].w : 0) * 0.17

    FileView {
        path: Qt.resolvedUrl("../../assets/train/train.json").toString().replace("file://", "")
        onLoaded: { try { win.spec = JSON.parse(text()); } catch (e) {} }
    }

    // the time since this train set off, seconds
    property real t: 0
    property real start: 0
    FrameAnimation {
        running: Trainset.running && win.length > 0
        onTriggered: {
            win.t += Math.min(frameTime, 0.05);
            // gone off the right edge: another, or the last
            if (win.trainX > win.width) {
                if (Trainset.on) win.start = win.t + win.gap;
                else Trainset.running = false;
            }
        }
    }
    readonly property real trainX: -length + speed * (t - start)

    // ---- the train
    Row {
        id: train
        x: win.trainX
        anchors.bottom: parent.bottom
        spacing: -1
        Repeater {
            model: win.cars
            Image {
                required property var modelData
                required property int index
                width: modelData.w
                height: modelData.h
                anchors.bottom: parent.bottom
                source: Qt.resolvedUrl("../../assets/train/" + modelData.name + ".png")
                sourceSize: Qt.size(Math.round(width * 2), Math.round(height * 2))
                smooth: true
                mipmap: true
                // a slight rock on the rails, each carriage in its own time
                transform: Translate { y: -0.5 + 0.5 * Math.sin(win.t * 7 + index * 1.7) }
            }
        }
    }

    // ---- steam, drifting back from the chimney and up, thinning out
    readonly property int puffs: 16
    readonly property real every: 0.14          // s between puffs
    readonly property real life: puffs * every
    Repeater {
        model: win.puffs
        Image {
            required property int index
            readonly property string file: (win.spec.steam || [])[index % Math.max(1, (win.spec.steam || []).length)] || ""
            // how long ago this puff left the chimney, and where the chimney was then
            readonly property real age: ((win.t - index * win.every) % win.life + win.life) % win.life
            readonly property real bornX: -win.length + win.speed * (win.t - age - win.start) + win.length - win.chimneyBack
            readonly property real k: age / win.life
            visible: file !== "" && Trainset.running && bornX > -40 && win.t - age > win.start
            source: file !== "" ? Qt.resolvedUrl("../../assets/train/" + file) : ""
            width: 18 + 34 * k
            height: width
            fillMode: Image.PreserveAspectFit
            smooth: true
            x: bornX - width / 2 - 14 * age
            y: win.height - 36 - height / 2 - 30 * age - 6 * k * k
            opacity: 0.8 * (1 - k) * Math.min(1, age * 8)
        }
    }
}
