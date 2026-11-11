import QtQuick
import qs.theme

// Button (section 8): caps label in a 1.5 px rule.ink box. Hover fills it
// with paper.raised and underlines the label; pressing turns the label
// accent.ink and pushes the box 1 px into the paper. `primary` inks the
// whole button in accent.ink.
Item {
    id: root

    property string text: ""
    property bool primary: false
    property bool available: true
    signal clicked()

    implicitWidth: label.implicitWidth + 28
    implicitHeight: 28

    Rectangle {
        id: box
        width: root.width
        height: root.height
        y: mouse.pressed ? 1 : 0
        color: mouse.containsMouse && root.available ? Theme.paperRaised : "transparent"
        border.width: Theme.rule
        border.color: root.primary ? Theme.accent : Theme.ruleInk

        InkText {
            id: label
            anchors.centerIn: parent
            text: root.text
            caps: true
            tracking: 0.08
            font.pixelSize: Theme.sizeTitle
            font.bold: true
            font.underline: mouse.containsMouse && root.available
            color: !root.available ? Theme.faded : (mouse.pressed || root.primary) ? Theme.accent : Theme.graphite
        }

        Rectangle {
            visible: !root.available
            anchors.verticalCenter: label.verticalCenter
            anchors.left: label.left
            anchors.right: label.right
            height: 1
            color: Theme.faded
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.available
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
