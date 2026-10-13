import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import qs.theme
import qs.components

// One card in the catalogue drawer: a ruled library index card (a madder
// rule along the top, faint blue lines below) with a typed tab on its top
// edge. The tabs sit left, centre or right in turn, like guide cards, so the
// names of the cards further back can be read over the card in front.
Item {
    id: card

    required property var app
    property int number: 0
    property string category: ""
    property int tabSlot: 0
    property bool face: true             // the front cards show their text
    property real shade: 0               // deeper in the drawer: darker
    property bool current: false

    readonly property int tabWidth: 168
    readonly property int tabHeight: 30
    readonly property int line: 27       // the blue ruling

    // the tab, standing up from the card's top edge
    Rectangle {
        id: tab
        x: 22 + card.tabSlot * (card.width - 44 - card.tabWidth) / 2
        y: -card.tabHeight + 4
        width: card.tabWidth
        height: card.tabHeight + 6
        radius: 5
        color: Theme.paperCard
        border.width: 1
        border.color: Qt.rgba(Theme.ruleInk.r, Theme.ruleInk.g, Theme.ruleInk.b, 0.35)

        InkText {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            y: 6
            text: card.app ? card.app.name : ""
            caps: true
            tracking: 0.08
            elide: Text.ElideRight
            font.pixelSize: 13
            color: card.current ? Theme.graphite : Theme.soft
        }
        // deeper in the drawer, less light reaches the card
        Rectangle { anchors.fill: parent; radius: parent.radius; color: "black"; opacity: card.shade; visible: opacity > 0.01 }
    }

    Rectangle {
        id: body
        anchors.fill: parent
        radius: 2
        color: Theme.paperCard
        border.width: 1
        border.color: Qt.rgba(Theme.ruleInk.r, Theme.ruleInk.g, Theme.ruleInk.b, 0.35)

        Grain { anchors.fill: parent; strength: 0.9 }
        Rectangle { anchors.fill: parent; color: "black"; opacity: card.shade; visible: opacity > 0.01; z: 10 }

        // the ruling
        Rectangle { x: 10; y: 46; width: parent.width - 20; height: 1.6; color: Theme.madder; opacity: 0.75 }
        Repeater {
            model: Math.max(0, Math.floor((card.height - 60) / card.line))
            Rectangle {
                required property int index
                x: 10
                y: 46 + (index + 1) * card.line
                width: card.width - 20
                height: 1
                color: Theme.accent
                opacity: 0.22
            }
        }
    }

    Item {
        anchors.fill: parent
        visible: card.face && card.app

        InkText {
            x: 24
            y: 16
            text: "No. " + String(card.number).padStart(3, "0")
            font.pixelSize: 14
            color: Theme.faded
        }
        InkText {
            anchors.right: parent.right
            anchors.rightMargin: 24
            y: 16
            text: card.category
            caps: true
            tracking: 0.1
            font.pixelSize: 13
            color: Theme.faded
        }

        // typed on the ruling
        InkText {
            id: title
            x: 24
            y: 46 + card.line - 25
            width: parent.width - 48 - (photo.visible ? photo.width + 16 : 0)
            text: card.app ? card.app.name : ""
            elide: Text.ElideRight
            font.pixelSize: 24
            color: Theme.graphite
        }
        InkText {
            x: 24
            y: 46 + 2 * card.line - 19
            width: title.width
            text: card.app ? (card.app.genericName || "") : ""
            elide: Text.ElideRight
            font.pixelSize: 16
            color: Theme.soft
        }
        InkText {
            x: 24
            y: 46 + 3 * card.line - 19
            width: title.width
            text: card.app ? (card.app.comment || "") : ""
            elide: Text.ElideRight
            font.pixelSize: 15
            color: Theme.faded
        }

        // the application's own picture, pasted in like a photograph
        Item {
            id: photo
            visible: icon.status === Image.Ready
            anchors.right: parent.right
            anchors.rightMargin: 26
            y: 62
            width: 76
            height: 76
            Rectangle { anchors.fill: parent; color: Theme.paperRaised; border.width: 1; border.color: Qt.rgba(Theme.ruleInk.r, Theme.ruleInk.g, Theme.ruleInk.b, 0.3) }
            Image {
                id: icon
                anchors.centerIn: parent
                width: 52
                height: 52
                sourceSize: Qt.size(104, 104)
                source: card.face && card.app && card.app.icon ? Quickshell.iconPath(card.app.icon, true) : ""
                visible: false
                asynchronous: true
            }
            Desaturate {
                anchors.fill: icon
                source: icon
                desaturation: 0.8
                opacity: 0.85
            }
            // photo corners
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    width: 12; height: 12
                    rotation: 45
                    color: Theme.soft
                    opacity: 0.55
                    x: (index % 2 === 0 ? -6 : photo.width - 6)
                    y: (index < 2 ? -6 : photo.height - 6)
                }
            }
        }

        InkText {
            visible: card.current
            x: 24
            y: 46 + 5 * card.line - 19
            text: "Return to take it out"
            font.pixelSize: 13
            color: Theme.faded
            opacity: 0.8
        }
    }

}
