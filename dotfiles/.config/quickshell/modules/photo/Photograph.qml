import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.services
import qs.components

// A screenshot, developed: the screen flashes like a magnesium lamp, and the
// shot drops onto the desk as a bordered print at a slight angle, held by a
// paperclip, with its date typed underneath. After a few seconds it is
// filed: an envelope comes up behind it, the print slides in, the flap folds
// down, the archive's postmark lands on it and it is sent off (the file is
// already in ~/Pictures/Archive and on the clipboard).
//   hover      keep it on the desk        click    open it
//   right      file it now                middle   pin it (stays till clicked)
// archive-screenshot calls: qs ipc call photo develop <file>
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
        // the flash at once; the print drops once the picture has loaded, so
        // it lands where its real size puts it
        clear();
        shutter.restart();
        waiting = true;
        if (picture.status === Image.Ready || picture.status === Image.Error) startDrop();
    }
    property bool waiting: false
    function startDrop(): void {
        if (!waiting) return;
        waiting = false;
        develop.restart();
    }

    // off the desk at once (before the next screenshot is taken)
    function clear(): void {
        waiting = false;
        develop.stop();
        shutter.stop();
        fileAway.stop();
        linger.stop();
        flash.opacity = 0;
        unpack();
        shot.visible = false;
        shot.filing = false;
        clip.opacity = 0;
    }
    function fileNow(): void { if (!fileAway.running) fileAway.restart(); }

    // ------------------------------------------------------------ the flash
    Rectangle {
        id: flash
        anchors.fill: parent
        color: Theme.night > 0.5 ? "#dfe9f7" : "#fffdf8"
        opacity: 0
    }

    // ------------------------------------------------------------ the shot
    // in the bottom right-hand corner, just above the bar
    readonly property real restX: width - shot.width - 30
    readonly property real restY: height - Theme.barHeight - shot.height - 26
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
            onStatusChanged: if (status === Image.Ready || status === Image.Error) win.startDrop()
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
                win.fileNow();
            }
        }
    }

    // flash, then the shot falls onto the desk and the clip goes on
    SequentialAnimation {
        id: develop
        ScriptAction { script: { fileAway.stop(); shot.filing = false; shot.visible = false; } }
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
            NumberAnimation { target: shot; property: "opacity"; to: 1; duration: Theme.dur(200) }
            NumberAnimation { target: shot; property: "scale"; to: 1; duration: Theme.dur(520); easing.type: Easing.OutBack; easing.overshoot: 0.8 }
            NumberAnimation { target: shot; property: "y"; to: win.restY; duration: Theme.dur(520); easing.type: Easing.OutBounce }
            NumberAnimation { target: shot; property: "rotation"; to: win.restAngle; duration: Theme.dur(560); easing.type: Easing.OutBack }
        }
        NumberAnimation { target: clip; property: "opacity"; from: 0; to: 1; duration: Theme.dur(120) }
        NumberAnimation { target: clip; property: "y"; from: -30; to: -16; duration: Theme.dur(140); easing.type: Easing.OutBack }
        // from here on it follows its resting place (the picture's size, the screen)
        ScriptAction { script: { shot.x = Qt.binding(() => win.restX); shot.y = Qt.binding(() => win.restY); linger.restart(); } }
    }

    // the magnesium flash
    SequentialAnimation {
        id: shutter
        NumberAnimation { target: flash; property: "opacity"; to: 0.6; duration: Theme.dur(60) }
        NumberAnimation { target: flash; property: "opacity"; to: 0; duration: Theme.dur(420); easing.type: Easing.OutCubic }
    }

    Timer {
        id: linger
        interval: 6000
        onTriggered: if (hover.containsMouse || win.pinned) restart(); else win.fileNow()
    }

    // ------------------------------------------------------------ the envelope
    // Comes up behind the print; the print is put into it (moved inside,
    // between its back and its pocket), the flap folds over, the postmark
    // lands, and off it goes.
    readonly property real envW: 400
    readonly property real envH: 250
    readonly property color envPaper: Theme.night > 0.5 ? Theme.paperRaised : "#e2ddd3"
    property Item shotHome: null

    // the print back on the desk (after filing, or if filing is cut short)
    function unpack(): void {
        if (shotHome !== null) {
            shot.parent = shotHome;
            shotHome = null;
        }
        envelope.visible = false;
        postmark.visible = false;
    }

    Item {
        id: envelope
        visible: false
        width: win.envW
        height: win.envH
        transformOrigin: Item.Center
        property real rise: 0             // the envelope's own parts, coming up from below
        property real flapAngle: 180      // 180 open (standing up behind), 0 folded down
        // sent: 0 on the desk, 1 gone over the top right; a little dip
        // first, as it is picked up
        property real baseX: 0
        property real baseY: 0
        property real baseRot: 0
        property real sent: 0
        readonly property real away: sent * sent * sent
        x: baseX + (win.width + 120 - baseX) * away
        y: baseY + 40 * sent - 420 * away
        rotation: baseRot + 22 * away
        scale: 1 - 0.28 * away

        RectangularGlow {
            anchors.fill: parent
            anchors.topMargin: 6 + envelope.rise
            anchors.bottomMargin: -envelope.rise
            glowRadius: 12
            spread: 0.1
            cornerRadius: 12
            color: Theme.shadow
            opacity: back.opacity
        }
        // the inside of its far wall, seen through the opening
        Rectangle {
            id: back
            y: envelope.rise
            width: parent.width
            height: parent.height
            color: Qt.darker(win.envPaper, 1.16)
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.2)
        }
        // the flap while it stands open, behind the print
        Item {
            id: flapBehind
            y: envelope.rise
            width: parent.width
            height: parent.height
            opacity: back.opacity
            visible: envelope.flapAngle > 90
            EnvelopeFlap { paper: win.envPaper; angle: envelope.flapAngle }
        }
        // where the print goes: anything of it below the envelope is out of sight
        Item {
            id: slot
            y: -700
            width: parent.width
            height: 700 + parent.height
            clip: true
        }
        // the pocket: the side and bottom flaps, folded and glued
        Canvas {
            id: pocket
            y: envelope.rise
            width: parent.width
            height: parent.height
            opacity: back.opacity
            property color paper: win.envPaper
            onPaperChanged: requestPaint()
            onPaint: {
                const g = getContext("2d");
                g.reset();
                const w = width, h = height;
                g.fillStyle = paper;
                g.beginPath();
                g.moveTo(0, 0); g.lineTo(w * 0.5, h * 0.47); g.lineTo(w, 0);
                g.lineTo(w, h); g.lineTo(0, h); g.closePath();
                g.fill();
                // the bottom flap a shade darker, over the sides
                g.fillStyle = Qt.rgba(0, 0, 0, 0.045);
                g.beginPath();
                g.moveTo(0, h); g.lineTo(w * 0.5, h * 0.5); g.lineTo(w, h); g.closePath();
                g.fill();
                // the folds and the cut edges
                g.strokeStyle = Qt.rgba(0, 0, 0, 0.22);
                g.lineWidth = 1;
                g.beginPath();
                g.moveTo(0, 0); g.lineTo(w * 0.5, h * 0.47); g.lineTo(w, 0);
                g.moveTo(1, h - 1); g.lineTo(w * 0.5, h * 0.5); g.lineTo(w - 1, h - 1);
                g.stroke();
                g.strokeStyle = Qt.rgba(0, 0, 0, 0.3);
                g.strokeRect(0.5, 0.5, w - 1, h - 1);
                // light along the fold of the bottom flap
                g.strokeStyle = Qt.rgba(1, 1, 1, 0.35);
                g.beginPath(); g.moveTo(3, h - 2); g.lineTo(w * 0.5, h * 0.5 + 2); g.lineTo(w - 3, h - 2); g.stroke();
            }
            InkText {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * 0.76
                text: "Pictures  ·  Archive."
                font.pixelSize: 12
                color: "#6e6c6d"
            }
        }
        // the flap once folded past upright, over the pocket
        Item {
            y: envelope.rise
            width: parent.width
            height: parent.height
            opacity: back.opacity
            visible: envelope.flapAngle <= 90
            EnvelopeFlap { paper: win.envPaper; angle: envelope.flapAngle }
        }
        Stamp {
            id: postmark
            visible: false
            kind: "oval"
            number: Qt.formatDate(new Date(), "d.M.yy")
            footer: "PICTURES"
            ink: Theme.accent
            seed: 7311
            scale: 0.66
            x: parent.width * 0.5 - width / 2 + 34
            y: parent.height * 0.52 - height / 2
        }
    }

    // filed: into the envelope, sealed, postmarked and sent off
    SequentialAnimation {
        id: fileAway
        ScriptAction {
            script: {
                linger.stop();
                shot.filing = true;
                // the envelope where the print is, turned as it is, a
                // little lower so the print stands over its opening (and
                // clear of the bar)
                const cx = shot.x + shot.width / 2, cy = shot.y + shot.height / 2;
                envelope.sent = 0;
                envelope.baseRot = shot.rotation;
                envelope.baseX = cx - win.envW / 2;
                envelope.baseY = Math.min(cy - win.envH / 2 + 34, win.height - Theme.barHeight - win.envH - 14);
                envelope.rise = 90;
                envelope.flapAngle = 180;
                back.opacity = 0;
                postmark.visible = false;
                envelope.visible = true;
                // the print into the envelope's slot, where it already stands
                win.shotHome = shot.parent;
                shot.parent = slot;
                shot.rotation = 0;
                shot.x = win.envW / 2 - shot.width / 2;
                shot.y = 700 + (cy - envelope.baseY) - shot.height / 2;
            }
        }
        // the envelope comes up behind; the print is made to fit
        ParallelAnimation {
            NumberAnimation { target: back; property: "opacity"; to: 1; duration: Theme.dur(110) }
            NumberAnimation { target: envelope; property: "rise"; to: 0; duration: Theme.dur(190); easing.type: Easing.OutCubic }
            NumberAnimation { target: clip; property: "opacity"; to: 0; duration: Theme.dur(110) }
            NumberAnimation { target: shot; property: "scale"; to: (win.envW - 40) / shot.width; duration: Theme.dur(190); easing.type: Easing.InOutQuad }
        }
        // slid in
        NumberAnimation {
            target: shot; property: "y"
            to: 700 + 12 - shot.height * (1 - (win.envW - 40) / shot.width) / 2
            duration: Theme.dur(230); easing.type: Easing.InOutCubic
        }
        // the flap folds over
        NumberAnimation { target: envelope; property: "flapAngle"; to: 0; duration: Theme.dur(190); easing.type: Easing.InOutQuad }
        // postmarked
        ScriptAction { script: { postmark.visible = true; postmark.press(); Sounds.play("message"); } }
        PauseAnimation { duration: Theme.dur(170) }
        // and sent: picked up off the desk and away over the top right
        NumberAnimation { target: envelope; property: "sent"; from: 0; to: 1; duration: Theme.dur(420) }
        ScriptAction {
            script: {
                win.unpack();
                shot.visible = false;
                shot.filing = false;
                shot.scale = 1;
                clip.opacity = 0;
            }
        }
    }
}
