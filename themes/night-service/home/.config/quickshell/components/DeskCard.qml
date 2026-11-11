import QtQuick
import qs.services
import qs.theme

// A card lying loose on the desk. Drag it anywhere (it stays on the
// screen); right-click to file it away. Desk.restore() lays it back at
// (homeX, homeY), where the layout puts it.
Item {
    id: card

    required property string name
    property bool wanted: true          // the settings may leave a card out
    property real homeX: 0
    property real homeY: 0
    // its place in the order the desk is laid out at login (0 = first)
    property int order: 0
    default property alias content: holder.data

    implicitWidth: holder.childrenRect.width
    implicitHeight: holder.childrenRect.height
    x: homeX
    y: homeY
    visible: wanted && !Desk.isClosed(name)

    // laid on the desk at login, one card after another: it comes down a
    // little from above and settles; picked up, it rises and turns a hair
    property real arrived: 0
    opacity: arrived
    transform: [
        Translate { y: -14 * (1 - card.arrived) },
        Scale {
            origin.x: card.width / 2
            origin.y: card.height / 2
            xScale: 1 + 0.02 * (1 - card.arrived) + 0.018 * card.held
            yScale: xScale
        },
        Rotation {
            origin.x: card.width / 2
            origin.y: card.height / 2
            angle: 0.7 * card.held
        }
    ]
    property real held: drag.active ? 1 : 0
    Behavior on held { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    SequentialAnimation {
        running: true
        PauseAnimation { duration: 260 + 120 * card.order }
        NumberAnimation { target: card; property: "arrived"; to: 1; duration: Theme.dur(460); easing.type: Easing.OutCubic }
    }

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
