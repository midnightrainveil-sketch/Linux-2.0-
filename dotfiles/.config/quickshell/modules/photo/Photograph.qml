import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.services
import qs.components

// A screenshot, developed: the screen flashes like a magnesium lamp, and the
// shot drops onto the desk as a bordered print at a slight angle, held by a
// paperclip, with its date typed underneath. After a few seconds it files
// itself away down into the bar (the file is already in ~/Pictures/Archive
// and on the clipboard).
//   hover      keep it on the desk        click    open it
//   right      file it now                middle   pin it (stays till clicked)
// archive-screenshot calls: qs ipc call photo show <file>
PanelWindow {
    id: win

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "archive-photograph"
    color: "transparent"
    visible: flash.opacity > 0.003 || shot.visible
    mask: Region { item: shot.visible && !shot.filing ? shot : null }

    property string path: ""
    property string taken: ""
    property bool pinned: false

    function show(file: string): void {
        path = file;
        const d = new Date();
        taken = "Record, " + Qt.formatDateTime(d, "d MMM yyyy, HH:mm") + ".";
        pinned = false;
        restAngle = Math.random() * 8 - 5;
        Sounds.play("capture");
        develop.restart();
    }

    // off the desk at once (before the next screenshot is taken)
    function clear(): void {
        develop.stop();
        fileAway.stop();
        linger.stop();
        flash.opacity = 0;
        shot.visible = false;
        shot.filing = false;
        clip.opacity = 0;
    }

    // ------------------------------------------------------------ the flash
    Rectangle {
        id: flash
        anchors.fill: parent
        color: Theme.night > 0.5 ? "#dfe9f7" : "#fffdf8"
        opacity: 0
    }

    // ------------------------------------------------------------ the shot
    readonly property real restX: width - Theme.margin - Theme.recordWidth - shot.width - 40
    readonly property real restY: height - Theme.barHeight - shot.height - 34
    property real restAngle: -3

    Item {
        id: shot
        property bool filing: false
        visible: false
        width: picture.width + 28
        height: picture.height + 64
        x: win.restX
        y: win.restY
        transformOrigin: Item.Center

        RectangularGlow {
            anchors.fill: parent
            anchors.topMargin: 6
            glowRadius: 14
            spread: 0.1
            cornerRadius: 16
            color: Theme.shadow
        }
        // the shot's white border (cream at night) and the picture
        Rectangle {
            anchors.fill: parent
            color: Theme.night > 0.5 ? "#e6e1d6" : "#f4f1ea"
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.12)
        }
        Image {
            id: picture
            x: 14
            y: 14
            // landscape shots 330 wide, tall ones 230 high at most
            readonly property real ratio: implicitHeight > 0 ? implicitWidth / implicitHeight : 1.6
            width: ratio >= 1 ? 330 : Math.max(120, 300 * ratio)
            height: width / ratio
            source: win.path === "" ? "" : "file://" + win.path
            sourceSize.width: 660
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            cache: false
            smooth: true
            mipmap: true
        }
        InkText {
            anchors.left: picture.left
            anchors.right: picture.right
            y: picture.y + picture.height + 12
            text: win.taken
            elide: Text.ElideRight
            font.pixelSize: 14
            color: "#3e3d42"
        }
        InkText {
            anchors.right: picture.right
            y: picture.y + picture.height + 32
            text: "Copied. Filed in Pictures/Archive."
            font.pixelSize: 11
            color: "#6e6c6d"
        }

        // the paperclip over the top edge
        Canvas {
            id: clip
            x: 26
            y: -16
            width: 26
            height: 64
            opacity: 0
            onPaint: {
                const g = getContext("2d");
                g.reset();
                g.strokeStyle = "#8e9399";
                g.lineWidth = 2.4;
                g.lineCap = "round";
                // an elongated double loop
                g.beginPath();
                g.moveTo(18, 48);
                g.lineTo(18, 10); g.arc(12, 10, 6, 0, Math.PI, true);
                g.lineTo(6, 54); g.arc(13, 54, 7, Math.PI, 0, true);
                g.lineTo(20, 18); g.arc(16, 18, 4, 0, Math.PI, true);
                g.lineTo(12, 44);
                g.stroke();
                g.strokeStyle = "rgba(255,255,255,0.55)";
                g.lineWidth = 0.8;
                g.beginPath(); g.moveTo(17, 46); g.lineTo(17, 12); g.stroke();
            }
        }

        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: e => {
                if (e.button === Qt.MiddleButton) { win.pinned = !win.pinned; return; }
                if (e.button === Qt.LeftButton && win.path !== "") Quickshell.execDetached(["xdg-open", win.path]);
                fileAway.restart();
            }
        }
    }

    // flash, then the shot falls onto the desk and the clip goes on
    SequentialAnimation {
        id: develop
        ScriptAction { script: { fileAway.stop(); shot.filing = false; shot.visible = false; } }
        NumberAnimation { target: flash; property: "opacity"; to: 0.6; duration: Theme.dur(60) }
        ScriptAction {
            script: {
                shot.visible = true;
                shot.opacity = 0;
                shot.scale = 1.9;
                shot.rotation = win.restAngle - 10;
                shot.x = win.restX;
                shot.y = win.restY - 120;
            }
        }
        ParallelAnimation {
            NumberAnimation { target: flash; property: "opacity"; to: 0; duration: Theme.dur(420); easing.type: Easing.OutCubic }
            NumberAnimation { target: shot; property: "opacity"; to: 1; duration: Theme.dur(200) }
            NumberAnimation { target: shot; property: "scale"; to: 1; duration: Theme.dur(520); easing.type: Easing.OutBack; easing.overshoot: 0.8 }
            NumberAnimation { target: shot; property: "y"; to: win.restY; duration: Theme.dur(520); easing.type: Easing.OutBounce }
            NumberAnimation { target: shot; property: "rotation"; to: win.restAngle; duration: Theme.dur(560); easing.type: Easing.OutBack }
        }
        NumberAnimation { target: clip; property: "opacity"; from: 0; to: 1; duration: Theme.dur(120) }
        NumberAnimation { target: clip; property: "y"; from: -30; to: -16; duration: Theme.dur(140); easing.type: Easing.OutBack }
        ScriptAction { script: linger.restart() }
    }

    Timer {
        id: linger
        interval: 6000
        onTriggered: if (hover.containsMouse || win.pinned) restart(); else fileAway.restart()
    }

    // filed: it slides down into the bar's drawer
    SequentialAnimation {
        id: fileAway
        ScriptAction { script: { linger.stop(); shot.filing = true; } }
        ParallelAnimation {
            NumberAnimation { target: shot; property: "y"; to: win.height + 20; duration: Theme.dur(380); easing.type: Easing.InCubic }
            NumberAnimation { target: shot; property: "scale"; to: 0.5; duration: Theme.dur(380); easing.type: Easing.InCubic }
            NumberAnimation { target: shot; property: "rotation"; to: win.restAngle + 8; duration: Theme.dur(380) }
        }
        ScriptAction { script: { shot.visible = false; shot.filing = false; clip.opacity = 0; } }
    }
}
