import QtQuick
import QtQuick.Effects
import qs.theme
import qs.services
import qs.components

// Audio Archive: the cover as a desaturated print, track data, and a 3 px
// blue progress line. No. = release year of the current track.
// Click the print to play / pause; scroll over the card to skip.
IndexCard {
    id: card

    title: "Audio Archive"
    number: Media.year !== "" ? Media.year : (Media.active ? "----" : "")
    seed: 303

    Item {
        width: parent.width
        height: 130

        // the print
        Item {
            id: print
            x: Theme.cardPad
            y: 14
            width: 132
            height: 100

            Rectangle {
                anchors.fill: parent
                color: Theme.paperRaised
                border.width: 1
                border.color: Theme.ruleFaint
            }
            Image {
                id: art
                anchors.fill: parent
                anchors.margins: 1
                source: Media.art
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: false
            }
            MultiEffect {
                anchors.fill: art
                source: art
                visible: art.status === Image.Ready
                saturation: -1.0
                contrast: 0.08
                brightness: Theme.night > 0.5 ? -0.08 : 0.02
                opacity: 0.92
            }
            Grain { anchors.fill: parent; strength: 1.6 }
            InkIcon {
                anchors.centerIn: parent
                visible: art.status !== Image.Ready
                name: "record"
                size: 34
                color: Theme.faded
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Media.toggle()
            }
        }

        Column {
            anchors.left: print.right
            anchors.leftMargin: 18
            anchors.right: parent.right
            anchors.rightMargin: Theme.cardPad
            y: 18
            spacing: 6

            InkText {
                width: parent.width
                text: Media.active ? Media.artist : "No recording playing."
                color: Media.active ? Theme.graphite : Theme.faded
                font.bold: Media.active
                elide: Text.ElideRight
            }
            InkText {
                width: parent.width
                visible: Media.active
                text: Media.title
                color: Theme.graphite
                font.bold: true
                elide: Text.ElideRight
            }
            InkText {
                width: parent.width
                visible: Media.active && Media.album !== ""
                text: Media.album
                elide: Text.ElideRight
            }
        }

        // progress: 1 px rule.faint track, 3 px accent.ink fill
        Item {
            id: progress
            anchors.left: print.right
            anchors.leftMargin: 18
            anchors.right: parent.right
            anchors.rightMargin: Theme.cardPad
            y: 92
            height: 3
            visible: Media.active
            Rectangle { y: 1; width: parent.width; height: 1; color: Theme.ruleFaint }
            Rectangle {
                width: parent.width * Media.progress
                height: 3
                color: Theme.accent
                Behavior on width { NumberAnimation { duration: 900; easing.type: Easing.Linear } }
            }
        }
        InkText {
            visible: Media.active
            anchors.left: progress.left
            y: progress.y + 12
            text: Media.time(Media.position)
            font.pixelSize: Theme.sizeLabel
        }
        InkText {
            visible: Media.active
            anchors.right: progress.right
            y: progress.y + 12
            text: Media.time(Media.length)
            font.pixelSize: Theme.sizeLabel
        }
    }

    WheelHandler {
        onWheel: e => e.angleDelta.y > 0 ? Media.previous() : Media.next()
    }
}
