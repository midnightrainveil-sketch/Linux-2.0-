import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Services.Notifications
import qs.theme
import qs.services
import qs.components

// One piece of Correspondence. It arrives as an envelope, sliding in from
// the right edge of the desk: who it is from, the summary typed as the
// address, a postage stamp, and a rubber stamp thumped over it (RECEIVED in
// blue; URGENT in madder for critical ones, which wait until dealt with).
//
//   click the envelope   it turns over, the flap lifts, and the letter slides
//                        out: the full card with the body and any buttons
//   click the letter     runs the default action and files it
//   right click          files it away unread
//   middle click         pins it with a tape strip
// An envelope left unopened goes down to the letter tray on the desk corner
// (LetterTray.qml); a letter that has been read is simply filed.
Item {
    id: root

    required property int nid
    required property int serial
    required property bool opened                  // came back from the tray: arrives unfolded
    readonly property var notification: Notifs.byId[nid] ?? null
    readonly property bool critical: Notifs.isCritical(notification)
    readonly property string stampWord: notification?.hints?.["x-archive-stamp"] ?? (critical ? "URGENT" : "RECEIVED")
    readonly property string imageUrl: {
        const i = notification?.image ?? "";
        return i.startsWith("/") ? "file://" + i : i;
    }
    property bool unfolded: opened
    property bool pinned: false
    property bool leaving: false

    readonly property int envHeight: 156
    readonly property color envPaper: Theme.night > 0.5 ? Qt.lighter(Theme.paperRaised, 1.08) : "#d9d0c1"

    width: 360
    height: unfolded ? card.height : envHeight
    Behavior on height { NumberAnimation { duration: Theme.dur(260); easing.type: Easing.OutCubic } }

    Component.onCompleted: opened ? reveal.start() : arrive.start()

    // ------------------------------------------------------------ arriving
    // the envelope slides in from the right edge, turning a little as it lands
    SequentialAnimation {
        id: arrive
        ParallelAnimation {
            NumberAnimation { target: sheet; property: "x"; from: 420; to: 0; duration: Theme.dur(420); easing.type: Easing.OutCubic }
            NumberAnimation { target: sheet; property: "rotation"; from: 9; to: root.restAngle; duration: Theme.dur(520); easing.type: Easing.OutBack; easing.overshoot: 2.2 }
            NumberAnimation { target: sheet; property: "opacity"; from: 0; to: 1; duration: Theme.dur(160) }
        }
        ScriptAction { script: stamp.press() }
    }
    readonly property real restAngle: ((nid * 37) % 5 - 2) * 0.6

    // back from the tray: the letter is simply laid out again
    ParallelAnimation {
        id: reveal
        NumberAnimation { target: sheet; property: "opacity"; from: 0; to: 1; duration: Theme.durWindowIn }
        NumberAnimation { target: sheet; property: "y"; from: 14; to: 0; duration: Theme.durWindowIn; easing.type: Easing.Bezier; easing.bezierCurve: Theme.place }
    }

    // ------------------------------------------------------------ opening
    function open() {
        if (unfolded || opening.running || leaving) return;
        opening.start();
    }
    SequentialAnimation {
        id: opening
        // turn it over
        NumberAnimation { target: envelope; property: "flip"; to: 180; duration: Theme.dur(300); easing.type: Easing.InOutCubic }
        // lift the flap
        NumberAnimation { target: envelope; property: "flap"; to: 172; duration: Theme.dur(230); easing.type: Easing.OutCubic }
        // the letter comes up out of it
        NumberAnimation { target: peek; property: "y"; to: -70; duration: Theme.dur(240); easing.type: Easing.OutCubic }
        // and is laid out on the desk; the envelope slips away underneath
        ScriptAction { script: root.unfolded = true }
        ParallelAnimation {
            NumberAnimation { target: card; property: "opacity"; from: 0; to: 1; duration: Theme.dur(220) }
            NumberAnimation { target: card; property: "y"; from: -30; to: 0; duration: Theme.dur(260); easing.type: Easing.OutCubic }
            NumberAnimation { target: envelope; property: "opacity"; to: 0; duration: Theme.dur(200) }
            NumberAnimation { target: envelope; property: "y"; to: 50; duration: Theme.dur(260); easing.type: Easing.InCubic }
        }
    }

    // ------------------------------------------------------------ leaving
    // filed (read), dismissed, or sent down to the tray (unread)
    // `action` (a notification action) runs once the card is gone: running
    // it can close the notification at once, which would cut the animation
    function leave(how, action) {
        if (leaving) return;
        leaving = true;
        away.how = how;
        away.action = action ?? null;
        away.start();
    }
    SequentialAnimation {
        id: away
        property string how: "file"
        property var action: null
        ParallelAnimation {
            NumberAnimation { target: sheet; property: "opacity"; to: 0; duration: Theme.dur(away.how === "tray" ? 320 : 160); easing.type: Easing.InCubic }
            NumberAnimation { target: sheet; property: "y"; to: away.how === "tray" ? 140 : 6; duration: Theme.dur(away.how === "tray" ? 320 : 160); easing.type: Easing.InCubic }
            NumberAnimation { target: sheet; property: "scale"; to: away.how === "tray" ? 0.45 : 1; duration: Theme.dur(320); easing.type: Easing.InCubic }
            NumberAnimation { target: sheet; property: "x"; to: away.how === "dismiss" ? 60 : 0; duration: Theme.dur(160) }
        }
        ScriptAction {
            script: {
                const n = root.notification;
                if (away.action) away.action.invoke();
                if (away.how === "dismiss") Notifs.dismiss(n);
                else if (away.how === "tray") Notifs.toTray(n, root.serial);
                else Notifs.file(n);
            }
        }
    }

    // unread envelopes go to the tray after a while, read letters are filed;
    // urgent ones wait for you
    Timer {
        running: !root.critical && !root.pinned && !hover.containsMouse && !root.leaving && !opening.running
        interval: {
            const t = root.notification?.expireTimeout ?? -1;
            return t > 0 ? Math.max(3000, t) : (root.unfolded ? 8000 : 6500);
        }
        onTriggered: root.leave(root.unfolded ? "file" : "tray")
    }

    // ------------------------------------------------------------ the sheet
    Item {
        id: sheet
        width: root.width
        height: root.height
        opacity: 0
        transformOrigin: Item.Center

        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: e => {
                if (e.button === Qt.RightButton) {
                    root.leave("dismiss");
                } else if (e.button === Qt.MiddleButton) {
                    root.pinned = !root.pinned;
                } else if (!root.unfolded) {
                    root.open();
                } else {
                    const def = (root.notification?.actions ?? []).find(a => a.identifier === "default");
                    root.leave("dismiss", def);
                }
            }
        }

        // ---------------------------------------------------- the envelope
        Item {
            id: envelope
            width: root.width
            height: root.envHeight
            visible: !root.unfolded || opacity > 0.01
            opacity: root.opened ? 0 : 1
            property real flip: 0
            property real flap: 0
            readonly property bool backShown: flip > 90

            transform: Rotation {
                origin.x: envelope.width / 2
                origin.y: envelope.height / 2
                axis { x: 0; y: 1; z: 0 }
                angle: envelope.flip
            }

            RectangularGlow {
                anchors.fill: parent
                anchors.topMargin: 4
                glowRadius: 9
                spread: 0.15
                cornerRadius: 12
                color: Theme.shadow
            }

            // the front: from, address, postage, the rubber stamp
            Rectangle {
                id: front
                anchors.fill: parent
                visible: !envelope.backShown
                color: root.envPaper
                radius: 2
                border.width: 1
                border.color: Qt.rgba(Theme.ruleInk.r, Theme.ruleInk.g, Theme.ruleInk.b, 0.3)
                Grain { anchors.fill: parent; strength: 1.0 }

                InkText {
                    x: 20
                    y: 16
                    text: "From:"
                    font.pixelSize: 13
                    color: Theme.faded
                }
                InkText {
                    x: 66
                    y: 16
                    width: 190
                    text: root.notification?.appName || "Correspondence"
                    caps: true
                    tracking: 0.08
                    elide: Text.ElideRight
                    font.pixelSize: 13
                    color: root.critical ? Theme.madder : Theme.soft
                }

                // the summary, typed where the address goes
                InkText {
                    id: address
                    x: 64
                    y: 58
                    width: 196
                    text: root.notification?.summary ?? ""
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    font.pixelSize: 17
                    color: Theme.graphite
                }
                Rule {
                    x: 64
                    y: address.y + address.height + 6
                    width: 200
                    height: implicitHeight
                    weight: 1
                    color: Theme.ruleFaint
                    seed: 700 + root.nid
                }

                // postage: a perforated stamp with the archive's sprig
                Item {
                    id: postage
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    y: 14
                    width: 46
                    height: 56
                    Canvas {
                        anchors.fill: parent
                        readonly property color paper: Theme.paperCard
                        readonly property color ink: Theme.accent
                        onPaperChanged: requestPaint()
                        onPaint: {
                            const g = getContext("2d");
                            g.reset();
                            const w = width, h = height, r = 2.2;
                            g.fillStyle = String(paper);
                            g.fillRect(0, 0, w, h);
                            // perforations: bites along every edge
                            g.globalCompositeOperation = "destination-out";
                            for (let x = 3; x < w; x += 6) { g.beginPath(); g.arc(x, 0, r, 0, 6.3); g.arc(x, h, r, 0, 6.3); g.fill(); }
                            for (let y = 3; y < h; y += 6) { g.beginPath(); g.arc(0, y, r, 0, 6.3); g.arc(w, y, r, 0, 6.3); g.fill(); }
                            g.globalCompositeOperation = "source-over";
                            g.strokeStyle = String(ink);
                            g.lineWidth = 1;
                            g.strokeRect(5, 5, w - 10, h - 10);
                        }
                    }
                    InkIcon {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -3
                        name: "seedling"
                        size: 24
                        color: Theme.accent
                    }
                    InkText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 7
                        text: Clock.pad(root.serial % 100, 2)
                        font.pixelSize: 9
                        color: Theme.accent
                    }
                }

                // the rubber stamp, struck across the lower corner
                Item {
                    anchors.right: parent.right
                    anchors.rightMargin: 22
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 16
                    width: stamp.width
                    height: stamp.height
                    scale: 0.9
                    Stamp {
                        id: stamp
                        kind: "box"
                        word: root.stampWord
                        sub: "No. " + Clock.pad(root.serial, 4)
                        ink: root.critical ? Theme.madder : Theme.accent
                        seed: 33 + root.nid
                    }
                }

                // urgent letters are sealed in wax
                Rectangle {
                    visible: root.critical
                    x: 22
                    y: parent.height - 46
                    width: 30
                    height: 30
                    radius: 15
                    color: Theme.madder
                    border.width: 2
                    border.color: Qt.darker(Theme.madder, 1.3)
                    InkText { anchors.centerIn: parent; text: "U"; font.bold: true; font.pixelSize: 14; color: Qt.lighter(Theme.madder, 1.6) }
                }
            }

            // the back: flap, pocket, and the letter inside
            Item {
                id: back
                anchors.fill: parent
                visible: envelope.backShown
                // mirrored by the turn; turned back so its drawing is the right way round
                transform: Rotation { origin.x: back.width / 2; axis { x: 0; y: 1; z: 0 } angle: 180 }

                Rectangle {
                    anchors.fill: parent
                    color: Qt.darker(root.envPaper, 1.25)          // the inside, seen once the flap is up
                    radius: 2
                }
                // the letter, folded inside
                Rectangle {
                    id: peek
                    x: 18
                    y: 22
                    width: parent.width - 36
                    height: parent.height - 30
                    color: Theme.paperCard
                    border.width: 1
                    border.color: Qt.rgba(Theme.ruleInk.r, Theme.ruleInk.g, Theme.ruleInk.b, 0.3)
                    z: 2
                    Repeater {
                        model: 3
                        Rectangle { required property int index; x: 16; y: 18 + index * 14; width: (peek.width - 32) * (index === 2 ? 0.6 : 1); height: 1.2; color: Theme.faded; opacity: 0.5 }
                    }
                }
                // the pocket: the folded sides and bottom of the envelope's back
                Canvas {
                    anchors.fill: parent
                    z: 3
                    readonly property color paper: root.envPaper
                    onPaperChanged: requestPaint()
                    onPaint: {
                        const g = getContext("2d");
                        g.reset();
                        const w = width, h = height;
                        g.fillStyle = String(paper);
                        g.beginPath();
                        g.moveTo(0, h * 0.18); g.lineTo(w * 0.5, h * 0.62); g.lineTo(w, h * 0.18);
                        g.lineTo(w, h); g.lineTo(0, h); g.closePath();
                        g.fill();
                        g.strokeStyle = "rgba(0,0,0,0.18)";
                        g.lineWidth = 1;
                        g.beginPath(); g.moveTo(0, h); g.lineTo(w * 0.42, h * 0.55); g.moveTo(w, h); g.lineTo(w * 0.58, h * 0.55); g.stroke();
                        g.beginPath(); g.moveTo(0, h * 0.18); g.lineTo(w * 0.5, h * 0.62); g.lineTo(w, h * 0.18); g.stroke();
                    }
                }
                // the flap, hinged along the top
                Canvas {
                    id: flapShape
                    width: parent.width
                    height: parent.height * 0.6
                    z: envelope.flap < 90 ? 4 : 1
                    readonly property color paper: Qt.darker(root.envPaper, envelope.flap < 90 ? 1.0 : 1.12)
                    onPaperChanged: requestPaint()
                    transform: Rotation { origin.y: 0; axis { x: 1; y: 0; z: 0 } angle: envelope.flap }
                    onPaint: {
                        const g = getContext("2d");
                        g.reset();
                        const w = width, h = height;
                        g.fillStyle = String(paper);
                        g.beginPath(); g.moveTo(0, 0); g.lineTo(w, 0); g.lineTo(w * 0.5, h); g.closePath(); g.fill();
                        g.strokeStyle = "rgba(0,0,0,0.22)";
                        g.lineWidth = 1;
                        g.stroke();
                    }
                }
            }
        }

        // ---------------------------------------------------- the letter
        IndexCard {
            id: card
            width: root.width
            visible: root.unfolded
            opacity: root.opened ? 1 : 0
            title: root.notification?.appName || "Correspondence"
            number: Clock.pad(root.serial, 5)
            titleColor: root.critical ? Theme.madder : Theme.graphite
            seed: 900 + root.nid
            lift: hover.containsMouse ? 1.5 : 1.1

            Item {
                width: parent.width
                height: Math.max(textCol.implicitHeight, picture.height) + 26

                Image {
                    id: picture
                    x: Theme.cardPad
                    y: 13
                    width: visible ? 44 : 0
                    height: visible ? 44 : 0
                    visible: root.imageUrl !== ""
                    source: root.imageUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }

                Column {
                    id: textCol
                    anchors.left: picture.right
                    anchors.leftMargin: picture.visible ? 14 : Theme.headerPadH
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.headerPadH
                    y: 13
                    spacing: 4

                    InkText {
                        width: parent.width
                        text: root.notification?.summary ?? ""
                        color: Theme.graphite
                        font.bold: true
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                    InkText {
                        width: parent.width
                        visible: text !== ""
                        text: root.notification?.body ?? ""
                        wrapMode: Text.Wrap
                        maximumLineCount: 8
                        elide: Text.ElideRight
                    }
                    Flow {
                        width: parent.width
                        visible: actionRepeater.count > 0
                        spacing: 8
                        topPadding: 6
                        Repeater {
                            id: actionRepeater
                            model: (root.notification?.actions ?? []).filter(a => a.identifier !== "default")
                            ArchiveButton {
                                required property var modelData
                                text: modelData.text
                                onClicked: root.leave("file", modelData)
                            }
                        }
                    }
                }
            }
        }

        Tape {
            visible: root.pinned
            width: 70
            height: 18
            anchors.horizontalCenter: parent.horizontalCenter
            y: -8
            rotation: -3
            seed: 77
            z: 10
        }
    }
}
