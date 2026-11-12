import QtQuick
import qs.theme
import qs.services
import qs.components

// Notes: a short list to tick off (services/Notes.qml).
Box {
    id: card
    title: "Notes"
    readonly property int shown: Math.min(Notes.items.length, 7)
    height: headHeight + 14 + Math.max(1, shown) * 30 + 10

    Icon {
        parent: card.header
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        name: "edit"
        size: 20
        MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: Notes.edit() }
    }

    Label {
        visible: Notes.items.length === 0
        x: 24; y: 18
        text: "Nothing noted"
        color: Theme.dim
        font.pixelSize: 14
    }

    Column {
        x: 24; y: 14
        width: card.width - 44
        Repeater {
            model: Notes.items.slice(0, 7)
            Item {
                id: row
                required property var modelData
                required property int index
                width: parent.width
                height: 30
                Rectangle {
                    y: 6
                    width: 18; height: 18
                    color: "transparent"
                    border.color: Theme.ink
                    border.width: 1.5
                    Canvas {
                        anchors.fill: parent
                        visible: row.modelData.done
                        onPaint: {
                            const c = getContext("2d");
                            c.reset();
                            c.strokeStyle = Theme.accent;
                            c.lineWidth = 2.4;
                            c.lineCap = "round"; c.lineJoin = "round";
                            c.beginPath(); c.moveTo(4, 9.5); c.lineTo(8, 13.5); c.lineTo(15.5, 3.5); c.stroke();
                        }
                    }
                }
                Label {
                    x: 36
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 36
                    text: row.modelData.text
                    font.pixelSize: 15
                    color: row.modelData.done ? Theme.dim : Theme.ink
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Notes.toggle(row.index) }
            }
        }
    }
}
