import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.theme
import qs.services
import qs.components

// The field notebook: a botanist's cloth-bound field book lying open on the
// desk, written straight onto. Every page is a file in ~/Documents/Field
// Notes (the "notes" setting moves it), saved as you write, so the notes
// open anywhere. It opens at the last page written.
//
//   type                     write                   PageDown, the right-hand corner   turn on
//   Ctrl+N                   a fresh page            PageUp, the left-hand corner      turn back
//   Escape, click outside    close (it is all saved already)
PanelWindow {
    id: win

    readonly property string name: "notebook"
    readonly property bool shown: Panels.open === name

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "archive-notebook"
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"
    visible: shown || slide > 0.001
    mask: Region { item: win.shown ? catcher : null }

    // ---------------------------------------------------------------- the pages
    readonly property string dir: {
        const d = Settings.get("notes", "");
        if (d !== "") return d.replace(/^~/, Settings.home);
        return Settings.home + "/Documents/Field Notes";
    }
    property int count: 0                // pages written
    property int current: 1              // the right-hand page
    property bool listed: false

    // the two pages lying open, and the one turning
    property int leftNum: current - 1
    property int rightNum: current
    property int leafNum: 0
    property bool turning: false

    readonly property bool canBack: !turning && current > 1
    readonly property bool canOn: !turning && (current <= count || !right.blank)

    Process {
        id: lister
        command: ["sh", "-c", "mkdir -p \"$1\" && ls -1 \"$1\"", "sh", win.dir]
        stdout: StdioCollector {
            onStreamFinished: {
                let n = 0;
                for (const f of text.split("\n")) {
                    const m = f.match(/^(\d{4})\.md$/);
                    if (m) n = Math.max(n, parseInt(m[1], 10));
                }
                win.count = n;
                if (!win.listed) win.goTo(Math.max(1, n));
                win.listed = true;
            }
        }
    }

    function goTo(n: int): void {
        current = n;
        leftNum = n - 1;
        rightNum = n;
    }

    onShownChanged: {
        if (shown) {
            listed = false;
            lister.running = true;
            focusLater.restart();
        } else {
            right.save();
        }
    }
    Timer { id: focusLater; interval: 60; onTriggered: right.focusField() }

    // ---------------------------------------------------------------- turning
    property real leafAngle: 0
    property bool leafForward: true

    function turnOn(): void {
        if (!canOn) return;
        right.save();
        const s = current;
        leafNum = s;
        leafForward = true;
        rightNum = s + 1;               // the next page shows under the leaf
        turning = true;
        forward.restart();
    }
    function turnBack(): void {
        if (!canBack) return;
        right.save();
        const s = current;
        leafNum = s - 1;
        leafForward = false;
        leftNum = s - 2;                // the page before shows under the leaf
        turning = true;
        back.restart();
    }
    function freshPage(): void {
        if (turning) return;
        right.save();
        if (current === count + 1 || (current === count && right.blank)) { right.focusField(); return; }
        goTo(count + 1);
        focusLater.restart();
    }

    SequentialAnimation {
        id: forward
        NumberAnimation { target: win; property: "leafAngle"; from: 0; to: -180; duration: Theme.dur(560); easing.type: Easing.InOutCubic }
        ScriptAction { script: { win.current = win.leafNum + 1; win.leftNum = win.leafNum; win.turning = false; focusLater.restart(); } }
    }
    SequentialAnimation {
        id: back
        NumberAnimation { target: win; property: "leafAngle"; from: -180; to: 0; duration: Theme.dur(560); easing.type: Easing.InOutCubic }
        ScriptAction { script: { win.current = win.leafNum; win.rightNum = win.leafNum; win.turning = false; focusLater.restart(); } }
    }

    function key(e): void {
        const ctrl = e.modifiers & Qt.ControlModifier;
        if (e.key === Qt.Key_Escape) Panels.close();
        else if (e.key === Qt.Key_PageDown) turnOn();
        else if (e.key === Qt.Key_PageUp) turnBack();
        else if (ctrl && e.key === Qt.Key_N) freshPage();
        else return;
        e.accepted = true;
    }

    // ---------------------------------------------------------------- motion
    property real slide: shown ? 1 : 0
    Behavior on slide {
        NumberAnimation {
            duration: win.shown ? Theme.dur(520) : Theme.dur(260)
            easing.type: win.shown ? Easing.OutBack : Easing.InCubic
            easing.overshoot: 0.7
        }
    }

    // ---------------------------------------------------------------- the room
    Item { id: catcher; anchors.fill: parent }
    Rectangle {
        anchors.fill: parent
        color: Theme.night > 0.5 ? "#050b16" : "#1e1d22"
        opacity: 0.22 * win.slide
    }
    MouseArea {
        anchors.fill: parent
        onClicked: Panels.close()
    }
    HyprlandFocusGrab {
        windows: [win]
        active: win.shown
        onCleared: if (Panels.open === win.name) Panels.close()
    }

    // ---------------------------------------------------------------- the book
    Item {
        id: stage
        width: 1010
        height: 668
        anchors.horizontalCenter: parent.horizontalCenter
        y: win.height - Theme.barHeight - height - 14 + (1 - win.slide) * (height + 60)
        opacity: Math.min(1, win.slide * 3)

        MouseArea { anchors.fill: parent; onClicked: right.focusField() }

        readonly property real pageW: 470
        readonly property real pageH: 610
        readonly property real gutterX: width / 2
        readonly property real pageY: 26

        // the cloth covers
        DropShadow {
            anchors.fill: cover
            source: cover
            radius: 24
            cached: true                  // it never changes: blurred once, not every frame
            samples: 33
            verticalOffset: 10
            color: Qt.rgba(0, 0, 0, 0.42)
        }
        Rectangle {
            id: cover
            x: 8; y: 6
            width: parent.width - 16
            height: parent.height - 12
            radius: 7
            color: Theme.night > 0.5 ? "#0c1628" : "#3d4636"
            Grain { anchors.fill: parent; strength: 3.2 }
            // the boards' edges, worn lighter
            Rectangle {
                anchors.fill: parent
                radius: 7
                color: "transparent"
                border.width: 2
                border.color: Qt.rgba(1, 1, 1, 0.08)
            }
            // the spine, a little sunken
            Rectangle {
                x: parent.width / 2 - 14
                width: 28
                height: parent.height
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.0) }
                    GradientStop { position: 0.5; color: Qt.rgba(0, 0, 0, 0.3) }
                    GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.0) }
                }
            }
        }

        // the elastic band, slipped off to the side
        Rectangle {
            x: cover.x + cover.width - 26
            y: cover.y - 4
            width: 9
            height: cover.height + 8
            radius: 2
            color: "#1b1a1c"
            Rectangle { x: 2; width: 1; height: parent.height; color: Qt.rgba(1, 1, 1, 0.1) }
        }

        // the leaves under the open pages: more on the right while the book is young
        Repeater {
            model: 4
            Rectangle {
                required property int index
                x: stage.gutterX - stage.pageW - 1 - (index + 1) * Math.min(1.6, 0.3 + win.current * 0.05)
                y: stage.pageY + (index + 1) * 0.8
                width: stage.pageW
                height: stage.pageH
                color: Qt.darker(Theme.paperRaised, 1.03 + index * 0.025)
                border.width: 0.5
                border.color: Qt.rgba(0, 0, 0, 0.18)
            }
        }
        Repeater {
            model: 4
            Rectangle {
                required property int index
                x: stage.gutterX + 1 + (index + 1) * 1.6
                y: stage.pageY + (index + 1) * 0.8
                width: stage.pageW
                height: stage.pageH
                color: Qt.darker(Theme.paperRaised, 1.03 + index * 0.025)
                border.width: 0.5
                border.color: Qt.rgba(0, 0, 0, 0.18)
            }
        }

        NotePage {
            id: left
            x: stage.gutterX - width
            y: stage.pageY
            leftHand: true
            dir: win.dir
            number: win.leftNum
            active: win.listed
        }
        NotePage {
            id: right
            x: stage.gutterX
            y: stage.pageY
            dir: win.dir
            number: win.rightNum
            editable: !win.turning
            active: win.listed
            onKeyPressed: e => win.key(e)
            onEdited: if (number > win.count && !blank) win.count = number
        }

        // the stitching in the fold
        Repeater {
            model: 9
            Rectangle {
                required property int index
                x: stage.gutterX - 1
                y: stage.pageY + 30 + index * (stage.pageH - 60) / 8
                width: 2
                height: 14
                radius: 1
                color: Qt.rgba(Theme.ruleInk.r, Theme.ruleInk.g, Theme.ruleInk.b, 0.55)
            }
        }

        // turning corners
        Canvas {
            id: onCorner
            visible: win.canOn
            x: stage.gutterX + stage.pageW - width
            y: stage.pageY + stage.pageH - height
            width: 34; height: 34
            readonly property color paper: Theme.paperCard
            onPaperChanged: requestPaint()
            onPaint: {
                const g = getContext("2d");
                g.reset();
                g.fillStyle = Qt.rgba(0, 0, 0, 0.25);
                g.beginPath(); g.moveTo(34, 0); g.lineTo(34, 34); g.lineTo(0, 34); g.closePath(); g.fill();
                g.fillStyle = String(paper);
                g.beginPath(); g.moveTo(34, 0); g.lineTo(0, 34); g.lineTo(4, 4); g.closePath(); g.fill();
                g.strokeStyle = Qt.rgba(0, 0, 0, 0.25); g.lineWidth = 1; g.stroke();
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.turnOn() }
        }
        Canvas {
            visible: win.canBack
            x: stage.gutterX - stage.pageW
            y: stage.pageY + stage.pageH - height
            width: 34; height: 34
            readonly property color paper: Theme.paperCard
            onPaperChanged: requestPaint()
            onPaint: {
                const g = getContext("2d");
                g.reset();
                g.fillStyle = Qt.rgba(0, 0, 0, 0.25);
                g.beginPath(); g.moveTo(0, 0); g.lineTo(34, 34); g.lineTo(0, 34); g.closePath(); g.fill();
                g.fillStyle = String(paper);
                g.beginPath(); g.moveTo(0, 0); g.lineTo(34, 34); g.lineTo(30, 4); g.closePath(); g.fill();
                g.strokeStyle = Qt.rgba(0, 0, 0, 0.25); g.lineWidth = 1; g.stroke();
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.turnBack() }
        }

        // the ribbon marker, lying across the right-hand page and out of the book
        Canvas {
            x: stage.gutterX + 40
            y: stage.pageY - 6
            width: 40
            height: stage.pageH + 60
            readonly property color c: Theme.madder
            onCChanged: requestPaint()
            onPaint: {
                const g = getContext("2d");
                g.reset();
                const h = height;
                g.fillStyle = String(c);
                g.beginPath();
                g.moveTo(2, 0); g.lineTo(12, 0);
                g.bezierCurveTo(14, h * 0.4, 30, h * 0.7, 32, h - 14);
                g.lineTo(27, h - 22); g.lineTo(24, h - 10);
                g.bezierCurveTo(20, h * 0.7, 4, h * 0.4, 2, 0);
                g.closePath();
                g.fill();
                g.strokeStyle = Qt.rgba(0, 0, 0, 0.25);
                g.lineWidth = 0.8;
                g.stroke();
                g.strokeStyle = Qt.rgba(1, 1, 1, 0.15);
                g.beginPath(); g.moveTo(5, 0); g.bezierCurveTo(8, h * 0.4, 22, h * 0.7, 26, h - 18); g.stroke();
            }
        }

        // ------------------------------------------------------------ the leaf being turned
        Item {
            id: leaf
            visible: win.turning
            x: stage.gutterX
            y: stage.pageY
            width: stage.pageW
            height: stage.pageH
            transform: Rotation {
                origin.x: 0
                origin.y: leaf.height / 2
                axis { x: 0; y: 1; z: 0 }
                angle: win.leafAngle
            }
            // its front: the right-hand page as it was
            NotePage {
                visible: win.leafAngle > -90
                dir: win.dir
                number: win.leafNum
                active: win.turning
            }
            // its back: the same page, now on the left
            NotePage {
                visible: win.leafAngle <= -90
                leftHand: true
                dir: win.dir
                number: win.leafNum
                active: win.turning
                transform: Scale { origin.x: 235; xScale: -1 }
            }
            // the shade falling across it as it lifts
            Rectangle {
                anchors.fill: parent
                color: "black"
                opacity: 0.22 * Math.sin(-win.leafAngle * Math.PI / 180)
            }
        }
    }
}
