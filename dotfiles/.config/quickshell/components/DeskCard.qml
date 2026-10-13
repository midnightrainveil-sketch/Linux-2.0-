import QtQuick
import qs.services

// A card lying loose on the desk. Drag it anywhere (it stays on the
// screen); right-click to file it away. Desk.restore() lays it back at
// (homeX, homeY), where the layout puts it.
Item {
    id: card

    required property string name
    property bool wanted: true          // the settings may leave a card out
    property real homeX: 0
    property real homeY: 0
    default property alias content: holder.data

    implicitWidth: holder.childrenRect.width
    implicitHeight: holder.childrenRect.height
    x: homeX
    y: homeY
    visible: wanted && !Desk.isClosed(name)

    Item {
        id: holder
        width: card.width
        height: childrenRect.height
    }

    DragHandler {
        id: drag
        target: card
        cursorShape: active ? Qt.ClosedHandCursor : Qt.ArrowCursor
        xAxis.minimum: 0
        xAxis.maximum: card.parent ? card.parent.width - card.width : 0
        yAxis.minimum: 0
        yAxis.maximum: card.parent ? card.parent.height - card.height : 0
    }
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: Desk.close(card.name)
    }

    Connections {
        target: Desk
        function onRestored() {
            card.x = Qt.binding(() => card.homeX);
            card.y = Qt.binding(() => card.homeY);
        }
    }
}
