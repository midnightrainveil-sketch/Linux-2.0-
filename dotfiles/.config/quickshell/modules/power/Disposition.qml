import QtQuick
import Quickshell
import qs.theme
import qs.services
import qs.components

// Disposition (power menu): centre. A specimen-label list of what to do with
// the session, each with its key letter. Destructive actions ask once more.
BarPopup {
    id: popup
    name: "disposition"
    side: "middle"
    exclusiveKeys: true

    property int selected: 0
    property int confirming: -1

    readonly property var actions: [
        { key: "l", word: "Lock",      note: "Close the reading room.",  cmd: ["qs", "ipc", "call", "lock", "lock"], confirm: false },
        { key: "s", word: "Suspend",   note: "Leave the desk as it is.", cmd: ["systemctl", "suspend"],             confirm: false },
        { key: "o", word: "Log out",   note: "End the session.",         cmd: ["archive-session", "logout"],        confirm: true },
        { key: "r", word: "Reboot",    note: "Restart the machine.",     cmd: ["systemctl", "reboot"],              confirm: true },
        { key: "d", word: "Shut down", note: "Close the archive.",       cmd: ["systemctl", "poweroff"],            confirm: true }
    ]

    function run(i) {
        const a = actions[i];
        if (a.confirm && confirming !== i) { confirming = i; selected = i; return; }
        Panels.close();
        Quickshell.execDetached(a.cmd);
    }

    onOpened: { selected = 0; confirming = -1; keys.forceActiveFocus(); }

    IndexCard {
        id: card
        width: 500
        title: "Disposition"
        subtitle: "Of the present session."
        number: Clock.timeRecordNo
        labelWidth: 70
        seed: 707
        lift: 1.6

        Item {
            id: keys
            width: 1; height: 0
            focus: true
            Keys.onPressed: e => {
                if (e.key === Qt.Key_Escape) { Panels.close(); return; }
                if (e.key === Qt.Key_Down || e.key === Qt.Key_J) { popup.selected = (popup.selected + 1) % popup.actions.length; popup.confirming = -1; return; }
                if (e.key === Qt.Key_Up || e.key === Qt.Key_K) { popup.selected = (popup.selected + popup.actions.length - 1) % popup.actions.length; popup.confirming = -1; return; }
                if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { popup.run(popup.selected); return; }
                const i = popup.actions.findIndex(a => a.key === e.text.toLowerCase());
                if (i >= 0) popup.run(i);
            }
        }

        Repeater {
            model: popup.actions

            Item {
                id: row
                required property var modelData
                required property int index
                readonly property bool current: popup.selected === index
                readonly property bool asking: popup.confirming === index
                width: card.width
                height: Theme.rowHeight + 6

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: 4; anchors.rightMargin: 4
                    color: Theme.paperRaised
                    opacity: row.current || mouse.containsMouse ? 1 : 0
                }
                Rectangle { visible: row.current; x: 4; width: 2; height: parent.height; color: row.asking ? Theme.madder : Theme.accent }

                InkText {
                    id: key
                    x: Theme.headerPadH
                    anchors.verticalCenter: parent.verticalCenter
                    text: "(" + row.modelData.key + ")"
                    color: Theme.faded
                }
                Rule {
                    vertical: true
                    x: card.labelWidth
                    anchors.top: parent.top; anchors.bottom: parent.bottom
                    width: implicitWidth
                    seed: 710 + row.index
                }
                InkText {
                    id: word
                    anchors.left: parent.left
                    anchors.leftMargin: card.labelWidth + Theme.headerPadH
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.word + "."
                    color: row.asking ? Theme.madder : Theme.graphite
                }
                InkText {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.headerPadH
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.asking ? "Press again to confirm." : row.modelData.note
                    color: row.asking ? Theme.madder : Theme.faded
                    font.pixelSize: Theme.sizeLabel
                }
                Rule {
                    visible: row.index < popup.actions.length - 1
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.leftMargin: 6; anchors.rightMargin: 6
                    anchors.bottom: parent.bottom
                    height: implicitHeight
                    weight: 1
                    color: Theme.ruleFaint
                    seed: 720 + row.index
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: popup.selected = row.index
                    onClicked: popup.run(row.index)
                }
            }
        }
        Item { width: 1; height: 4 }
    }
}
