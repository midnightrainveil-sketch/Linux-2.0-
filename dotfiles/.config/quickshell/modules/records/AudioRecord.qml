import QtQuick
import QtQuick.Effects
import qs.theme
import qs.services
import qs.components

// Audio Archive, laid out to the reference card (485 x 226):
//   header band, rule at 42
//   the cover as a grey print | artist, title, album
//   progress: 4 px accent fill on a 2 px track, times under it
// No. = release year of the current track.
// Click the print to play / pause; scroll over the card to skip.
IndexCard {
    id: card

    title: "Audio Archive"
    number: Media.year !== "" ? Media.year : (Media.active ? "----" : "")
    seed: 303
    implicitHeight: 226

    Item {
        width: card.width
        height: 181

        // the print
        Item {
            id: photo
            x: 27
            y: 61 - 45
            width: 134
            height: 140

            Rectangle {
                anchors.fill: parent
                color: Theme.paperRaised
            }
            Image {
                id: art
                anchors.fill: parent
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
                contrast: 0.12
                brightness: Theme.night > 0.5 ? -0.08 : 0.0
            }
            Grain { anchors.fill: parent; strength: 1.6 }
            InkIcon {
                anchors.centerIn: parent
                visible: art.status !== Image.Ready
                name: "record"
                size: 40
                color: Theme.faded
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Media.toggle()
            }
        }

        Column {
            x: 184
            y: 72 - 45 - 11
            width: card.width - x - Theme.headerPadH
            spacing: 9
            InkText {
                width: parent.width
                text: Media.active ? Media.artist : "No recording playing."
                color: Media.active ? Theme.soft : Theme.faded
                elide: Text.ElideRight
            }
            InkText {
                width: parent.width
                visible: Media.active
                text: Media.title
                color: Theme.graphite
                elide: Text.ElideRight
            }
            InkText {
                width: parent.width
                visible: Media.active && Media.album !== ""
                text: Media.album
                color: Theme.soft
                elide: Text.ElideRight
            }
        }

        // progress
        Item {
            id: progress
            x: 185
            y: 171 - 45 - 2
            width: 459 - 185
            height: 4
            visible: Media.active
            Rectangle { y: 1; width: parent.width; height: 2; color: Theme.ruleFaint; opacity: 0.9 }
            Rectangle {
                width: parent.width * Media.progress
                height: 4
                color: Theme.accent
                Behavior on width { NumberAnimation { duration: 900; easing.type: Easing.Linear } }
            }
        }
        InkText {
            visible: Media.active
            x: progress.x
            y: 194 - 45 - 9
            text: Media.time(Media.position)
            font.pixelSize: Theme.sizeSmall
        }
        InkText {
            visible: Media.active
            x: progress.x + progress.width - width + 2
            y: 194 - 45 - 9
            text: Media.time(Media.length)
            font.pixelSize: Theme.sizeSmall
        }
    }

    WheelHandler {
        onWheel: e => e.angleDelta.y > 0 ? Media.previous() : Media.next()
    }
}
