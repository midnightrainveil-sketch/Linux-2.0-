import QtQuick
import qs.theme

// A typed query line, as on the catalogue's holder: a label, then what is
// typed, with a block caret blinking slowly. `key` passes on the keys the
// line itself does not use (arrows, Return, Escape).
Item {
    id: root

    property string label: "Find:"
    property alias text: input.text
    property alias input: input
    signal key(var event)

    function clear(): void { input.text = ""; }
    function take(): void { input.forceActiveFocus(); }

    implicitHeight: 34

    InkText {
        id: lbl
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        color: Theme.faded
        font.pixelSize: Theme.sizeLabel
    }
    TextInput {
        id: input
        anchors.left: lbl.right
        anchors.leftMargin: 8
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        font.family: Theme.typewriter
        font.pixelSize: 17
        color: Theme.graphite
        cursorVisible: false
        cursorDelegate: Item {}
        clip: true
        focus: true
        Keys.onPressed: e => root.key(e)

        Rectangle {
            x: input.cursorRectangle.x + 1
            y: input.cursorRectangle.y + 2
            width: 8
            height: input.cursorRectangle.height - 4
            color: Theme.graphite
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: input.activeFocus
                NumberAnimation { to: 1; duration: 0 }
                PauseAnimation { duration: 500 }
                NumberAnimation { to: 0; duration: 0 }
                PauseAnimation { duration: 500 }
            }
        }
    }
}
