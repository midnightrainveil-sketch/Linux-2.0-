import QtQuick
import QtQuick.Effects
import qs.theme
import qs.services
import qs.components

// Audio Archive, laid out to the reference card (485 x 226):
//   header band, rule at 42
//   the cover as a grey print (a black record when there is none) | artist, title, album
//   progress: 4 px accent fill on a 2 px track, times under it
// No. = release year of the current track.
// Click the print to play / pause; click anywhere else on the card for the
// gramophone (the music in ~/Music); scroll over the card to skip.
IndexCard {
    id: card

    // (under everything else, so the print keeps its own click, and a drag
    // still moves the card)
    MouseArea {
        parent: card
        anchors.fill: parent
        z: -1
        cursorShape: Qt.PointingHandCursor
        onClicked: Panels.toggle("phonograph")
    }

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
                visible: art.status === Image.Ready
            }
            // nothing to show: a black record, turning while music plays
            Item {
                id: blank
                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height) - 6
                height: width
                visible: art.status !== Image.Ready
                Canvas {
                    id: disc
                    anchors.fill: parent
                    onPaint: {
                        const g = getContext("2d");
                        g.reset();
                        const c = width / 2;
                        g.fillStyle = "#141316";
                        g.beginPath(); g.arc(c, c, c - 1, 0, Math.PI * 2); g.fill();
                        // the grooves
                        g.lineWidth = 0.6;
                        for (let r = c - 4; r > c * 0.38; r -= 2.2) {
                            g.strokeStyle = Qt.rgba(1, 1, 1, 0.035 + 0.03 * Math.abs(Math.sin(r * 0.7)));
                            g.beginPath(); g.arc(c, c, r, 0, Math.PI * 2); g.stroke();
                        }
                        // the label, plain paper, and the spindle hole
                        g.fillStyle = "#cfc9bf";
                        g.beginPath(); g.arc(c, c, c * 0.33, 0, Math.PI * 2); g.fill();
                        g.strokeStyle = "rgba(0,0,0,0.25)"; g.lineWidth = 1;
                        g.beginPath(); g.arc(c, c, c * 0.24, 0, Math.PI * 2); g.stroke();
                        g.fillStyle = "#141316";
                        g.beginPath(); g.arc(c, c, 3, 0, Math.PI * 2); g.fill();
                        // a mark on the label, so the turning shows
                        g.fillStyle = "rgba(122, 74, 70, 0.7)";
                        g.fillRect(c - 1, c - c * 0.3, 2, c * 0.12);
                    }
                    RotationAnimation on rotation {
                        running: Media.playing && blank.visible
                        loops: Animation.Infinite
                        from: 0; to: 360
                        duration: 1800
                    }
                }
                // the light on it, which does not turn
                Canvas {
                    anchors.fill: parent
                    onPaint: {
                        const g = getContext("2d");
                        g.reset();
                        const c = width / 2;
                        const sheen = g.createConicalGradient(c, c, -Math.PI / 4);
                        sheen.addColorStop(0.0, "rgba(255,255,255,0)");
                        sheen.addColorStop(0.07, "rgba(255,255,255,0.14)");
                        sheen.addColorStop(0.15, "rgba(255,255,255,0)");
                        sheen.addColorStop(0.5, "rgba(255,255,255,0)");
                        sheen.addColorStop(0.57, "rgba(255,255,255,0.09)");
                        sheen.addColorStop(0.65, "rgba(255,255,255,0)");
                        sheen.addColorStop(1.0, "rgba(255,255,255,0)");
                        g.fillStyle = sheen;
                        g.beginPath(); g.arc(c, c, c - 2, 0, Math.PI * 2); g.arc(c, c, c * 0.34, 0, Math.PI * 2, true); g.fill();
                    }
                }
            }
            Image {
                id: art
                anchors.fill: parent
                // our own player's track picture first, else what the player reports
                source: Gramophone.loaded && Gramophone.cover !== "" ? "file://" + Gramophone.cover : Media.art
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
            Grain { anchors.fill: parent; strength: 1.6; visible: art.status === Image.Ready }
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
