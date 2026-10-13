import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.theme
import qs.services
import qs.components

// One piece of Correspondence: a card titled with the app name, a typed body,
// and a stamp that lands on the corner on arrival (RECEIVED in blue, URGENT
// in madder for critical ones, which stay until dismissed).
// Left click: run the default action and file it. Right click: dismiss.
// Middle click: pin it (a tape strip holds it on the sheet).
Item {
    id: root

    required property int nid
    required property int serial
    readonly property var notification: Notifs.byId[nid] ?? null
    readonly property bool critical: Notifs.isCritical(notification)
    readonly property string stampWord: notification?.hints?.["x-archive-stamp"] ?? (critical ? "URGENT" : "RECEIVED")
    readonly property string imageUrl: {
        const i = notification?.image ?? "";
        return i.startsWith("/") ? "file://" + i : i;
    }
    property bool pinned: false
    property bool leaving: false

    width: 360
    height: card.height

    Component.onCompleted: arrive.start()

    // the card lands: rises 12 px into place and fades in, then the stamp presses
    ParallelAnimation {
        id: arrive
        NumberAnimation { target: sheet; property: "opacity"; to: 1; duration: Theme.durWindowIn; easing.type: Easing.Bezier; easing.bezierCurve: Theme.place }
        NumberAnimation { target: sheet; property: "y"; to: 0; duration: Theme.durWindowIn; easing.type: Easing.Bezier; easing.bezierCurve: Theme.place }
        onFinished: stamp.press()
    }

    function leave(dismiss) {
        if (leaving) return;
        leaving = true;
        away.dismissAfter = dismiss;
        away.start();
    }

    // lifted off: fades and drops 6 px
    SequentialAnimation {
        id: away
        property bool dismissAfter: false
        ParallelAnimation {
            NumberAnimation { target: sheet; property: "opacity"; to: 0; duration: Theme.durWindowOut; easing.type: Easing.Bezier; easing.bezierCurve: Theme.lift }
            NumberAnimation { target: sheet; property: "y"; to: 6; duration: Theme.durWindowOut; easing.type: Easing.Bezier; easing.bezierCurve: Theme.lift }
        }
        ScriptAction {
            script: away.dismissAfter ? Notifs.dismiss(root.notification) : Notifs.hide(root.notification)
        }
    }

    // ordinary letters are filed after a while; critical ones wait
    Timer {
        running: !root.critical && !root.pinned && !hover.containsMouse && !root.leaving
        interval: {
            const t = root.notification?.expireTimeout ?? -1;
            return t > 0 ? Math.max(3000, t) : 6500;
        }
        onTriggered: root.leave(false)
    }

    // the card moves inside this fixed slot, so the stack does not jump
    Item {
        id: sheet
        width: root.width
        height: root.height
        opacity: 0
        y: 12

        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: e => {
                if (e.button === Qt.RightButton) {
                    root.leave(true);
                } else if (e.button === Qt.MiddleButton) {
                    root.pinned = !root.pinned;
                } else {
                    const def = (root.notification?.actions ?? []).find(a => a.identifier === "default");
                    if (def) def.invoke();
                    root.leave(true);
                }
            }
        }

        IndexCard {
            id: card
            width: root.width
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
                    anchors.rightMargin: 120
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
                        maximumLineCount: 5
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
                                onClicked: { modelData.invoke(); root.leave(false); }
                            }
                        }
                    }
                }
            }
        }

        Stamp {
            id: stamp
            kind: "box"
            word: root.stampWord
            sub: "No. " + Clock.pad(root.serial, 4)
            ink: root.critical ? Theme.madder : Theme.accent
            seed: 33 + root.nid
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12
            scale: 0.85
        }

        Tape {
            visible: root.pinned
            width: 70
            height: 18
            anchors.horizontalCenter: parent.horizontalCenter
            y: -8
            rotation: -3
            seed: 77
        }
    }
}
