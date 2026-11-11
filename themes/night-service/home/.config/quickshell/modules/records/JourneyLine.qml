import QtQuick
import qs.theme
import qs.services
import qs.components

// The night's journey, for the foot of Compartment 19's desk: the line from
// Wien to Venezia drawn through its stops, and a tiny engine on it where the
// train is by the clock (it leaves at 21:40 and is in at 07:15). By day it
// waits at Venezia, and the card says when it leaves again.
Item {
    id: line
    implicitWidth: 700
    implicitHeight: 124

    readonly property var stops: [
        { name: "Wien", t: "21:40", at: 0.0 },
        { name: "Semmering", t: "23:10", at: 0.24 },
        { name: "Klagenfurt", t: "01:05", at: 0.47 },
        { name: "Villach", t: "02:05", at: 0.6 },
        { name: "Udine", t: "04:30", at: 0.8 },
        { name: "Venezia", t: "07:15", at: 1.0 }
    ]
    function mins(t: string): int { return Number(t.slice(0, 2)) * 60 + Number(t.slice(3, 5)); }
    // minutes since 21:40 (the departure), wrapping at a day
    readonly property int sinceDep: ((Clock.now.getHours() * 60 + Clock.now.getMinutes()) - mins("21:40") + 1440) % 1440
    readonly property int runMins: (mins("07:15") - mins("21:40") + 1440) % 1440
    readonly property bool running: sinceDep <= runMins
    // where along the line: between the two stops either side, by their times
    readonly property real progress: {
        if (!running) return 1;
        for (let i = 1; i < stops.length; i++) {
            const a = (mins(stops[i - 1].t) - mins("21:40") + 1440) % 1440;
            const b = (mins(stops[i].t) - mins("21:40") + 1440) % 1440;
            if (sinceDep <= b) return stops[i - 1].at + (stops[i].at - stops[i - 1].at) * (sinceDep - a) / Math.max(1, b - a);
        }
        return 1;
    }
    readonly property string caption: {
        if (!running) return "Arrived at Venezia S. Lucia, 07:15. Next departure from Wien, 21:40.";
        for (let i = 1; i < stops.length; i++)
            if (progress <= stops[i].at) return "Between " + stops[i - 1].name + " and " + stops[i].name + ". Due at " + stops[i].name + " " + stops[i].t + ".";
        return "";
    }

    Paper { anchors.fill: parent; seed: 1940; lift: 0.9 }

    // the route: a gently wandering line across the card
    readonly property real x0: 34
    readonly property real x1: width - 34
    readonly property real ly: 56
    function yAt(f: real): real { return ly + 6 * Math.sin(f * Math.PI * 3.2) - 3 * Math.sin(f * 11); }
    Canvas {
        anchors.fill: parent
        onWidthChanged: requestPaint()
        property color ink: Theme.soft
        property color done: Theme.madder
        property real p: line.progress
        onPChanged: requestPaint()
        onInkChanged: requestPaint()
        onPaint: {
            const g = getContext("2d");
            g.reset();
            const path = (from, to) => {
                g.beginPath();
                for (let i = 0; i <= 100; i++) {
                    const f = from + (to - from) * i / 100;
                    const x = line.x0 + (line.x1 - line.x0) * f, y = line.yAt(f);
                    if (i === 0) g.moveTo(x, y); else g.lineTo(x, y);
                }
            };
            // the line ahead: dashed, like a railway on an old map; behind: solid madder
            g.lineWidth = 2.2;
            g.strokeStyle = ink;
            g.setLineDash([5, 3]);
            path(p, 1); g.stroke();
            g.setLineDash([]);
            g.strokeStyle = done;
            g.lineWidth = 2.6;
            if (p > 0) { path(0, p); g.stroke(); }
        }
    }
    // the stops
    Repeater {
        model: line.stops
        Item {
            required property var modelData
            required property int index
            readonly property real cx: line.x0 + (line.x1 - line.x0) * modelData.at
            readonly property real cy: line.yAt(modelData.at)
            readonly property bool passed: modelData.at <= line.progress + 0.001
            Rectangle {
                x: parent.cx - 5; y: parent.cy - 5
                width: 10; height: 10; radius: 5
                color: parent.passed ? Theme.madder : Theme.paperCard
                border.width: 1.6
                border.color: parent.passed ? Theme.madder : Theme.soft
            }
            InkText {
                x: parent.cx - width / 2
                y: parent.cy + (parent.index % 2 ? 9 : -26)
                text: parent.modelData.name
                font.pixelSize: 12
                font.bold: parent.index === 0 || parent.index === line.stops.length - 1
                color: Theme.graphite
            }
            InkText {
                x: parent.cx - width / 2
                y: parent.cy + (parent.index % 2 ? 24 : -40)
                text: parent.modelData.t
                font.pixelSize: 10
                color: Theme.faded
            }
        }
    }
    // the train, where it is now
    InkIcon {
        readonly property real cx: line.x0 + (line.x1 - line.x0) * line.progress
        x: cx - width / 2
        y: line.yAt(line.progress) - height - 4
        name: "train"
        size: 22
        color: Theme.graphite
        Behavior on x { NumberAnimation { duration: 1200; easing.type: Easing.InOutQuad } }
    }
    InkText {
        x: line.x0; y: line.height - 24
        width: line.width - 2 * line.x0
        text: line.caption
        font.pixelSize: 12
        font.italic: true
        color: Theme.soft
        elide: Text.ElideRight
    }
}
