import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.services
import qs.components

// Notifications: cards under the notes, over whatever is open. A click
// opens what it is about; a right-click puts it away.
PanelWindow {
    id: win

    anchors { top: true; right: true }
    margins.top: Panels.mailY
    margins.right: Theme.edge
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: Theme.columnWidth
    implicitHeight: Math.max(1, stack.height)
    color: "transparent"
    visible: Notifs.popups.count > 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "viewfinder-mail"

    Column {
        id: stack
        width: parent.width
        spacing: 12
        Repeater {
            model: Notifs.popups
            Rectangle {
                id: card
                required property int nid
                required property string at
                required property bool stays
                readonly property var note: Notifs.byId[nid] ?? null
                width: stack.width
                height: 68
                color: Theme.panel
                border.color: Theme.ink
                border.width: 1

                Icon { x: 18; y: 11; name: "mail"; size: 22 }
                Label {
                    x: 58; y: 11
                    width: parent.width - 58 - 80
                    text: card.note?.summary || card.note?.appName || "Notice"
                    font.pixelSize: 16
                    tracking: 1.5
                }
                Label {
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    y: 12
                    text: card.at
                    font.pixelSize: 15
                }
                Rectangle { x: 24; y: 44; width: 9; height: 9; radius: 5; color: Theme.accent }
                Label {
                    x: 58; y: 39
                    width: parent.width - 58 - 14
                    text: (card.note?.body || card.note?.appName || "").replace(/\s+/g, " ")
                    font.pixelSize: 13
                }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: e => { if (e.button === Qt.RightButton) Notifs.dismiss(card.note); else Notifs.open(card.note); }
                }
                Timer { interval: 8000; running: !card.stays; onTriggered: Notifs.expire(card.nid) }
            }
        }
    }
}
