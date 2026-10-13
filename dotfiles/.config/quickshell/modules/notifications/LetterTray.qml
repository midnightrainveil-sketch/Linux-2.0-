import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.services
import qs.components

// The letter tray: envelopes nobody opened in time lie here, on the desk
// corner above the bar, in a slightly fanned pile with a typed count.
//   click     the newest comes back up and opens
//   right     file the whole pile away
PanelWindow {
    id: win

    readonly property int pad: 22
    anchors { bottom: true; right: true }
    margins.bottom: Theme.barHeight + 10 - pad
    margins.right: Theme.margin + 6 - pad
    implicitWidth: 190 + 2 * pad
    implicitHeight: 92 + 2 * pad
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "archive-letter-tray"
    color: "transparent"
    visible: Notifs.tray.count > 0 || pile.opacity > 0.01
    mask: Region { item: pile }

    Item {
        id: pile
        x: win.pad
        y: win.pad
        width: 190
        height: 92
        opacity: Notifs.tray.count > 0 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durFocus } }

        // the envelopes, newest on top; only the top three show. Each row of
        // the tray keeps its delegate, so a new arrival drops onto the pile
        // without the others being laid again
        Repeater {
            model: Notifs.tray
            Item {
                id: env
                required property int index
                readonly property int depth: index                                     // 0 = top
                visible: depth < 3
                width: 150
                height: 66
                x: 14 + depth * 9
                property real drop: 0
                y: 16 - depth * 5 + drop
                rotation: [-3, 5, -8][Math.min(depth, 2)]
                z: 10 - depth

                RectangularGlow {
                    anchors.fill: parent
                    anchors.topMargin: 2
                    glowRadius: 5
                    spread: 0.15
                    cornerRadius: 7
                    color: Theme.shadow
                }
                Rectangle {
                    anchors.fill: parent
                    radius: 2
                    color: Theme.night > 0.5 ? Qt.lighter(Theme.paperRaised, 1.08) : "#d9d0c1"
                    border.width: 1
                    border.color: Qt.rgba(Theme.ruleInk.r, Theme.ruleInk.g, Theme.ruleInk.b, 0.3)
                    Grain { anchors.fill: parent; strength: 1.0 }
                    // a little postage stamp and a line of address
                    Rectangle { anchors.right: parent.right; anchors.rightMargin: 8; y: 7; width: 18; height: 22; color: Theme.paperCard; border.width: 1; border.color: Theme.accent }
                    Rectangle { x: 34; y: 36; width: 70; height: 1.4; color: Theme.faded; opacity: 0.6 }
                    Rectangle { x: 34; y: 44; width: 50; height: 1.4; color: Theme.faded; opacity: 0.6 }
                }
                // the newest drops onto the pile
                Component.onCompleted: if (depth === 0) land.start()
                NumberAnimation { id: land; target: env; property: "drop"; from: -46; to: 0; duration: Theme.dur(300); easing.type: Easing.OutBack }
            }
        }

        // the count, typed on a slip tucked under the pile
        Rectangle {
            x: 0
            y: 60
            width: count.implicitWidth + 18
            height: 24
            rotation: -2
            z: 20
            color: Theme.paperCard
            border.width: 1
            border.color: Qt.rgba(Theme.ruleInk.r, Theme.ruleInk.g, Theme.ruleInk.b, 0.35)
            InkText {
                id: count
                anchors.centerIn: parent
                text: Notifs.tray.count === 1 ? "1 letter" : Notifs.tray.count + " letters"
                font.pixelSize: 13
                color: Theme.soft
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: e => {
                if (e.button === Qt.RightButton) {
                    while (Notifs.tray.count > 0) {
                        const n = Notifs.byId[Notifs.tray.get(0).nid];
                        Notifs.tray.remove(0);
                        if (n) n.dismiss();
                    }
                } else {
                    Notifs.fromTray();
                }
            }
        }
    }
}
