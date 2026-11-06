import QtQuick
import QtQuick.Effects
import qs.theme
import qs.services
import qs.components

// Night Service's keepsakes, loose on the desk (theme.json flavour
// "keepsakes"): the postcard of Venice (bottom left) and the Wagons-Lits
// luggage label (top left). Each can be picked up and carried anywhere, or
// filed away with a right click, like the record cards; the desk button
// lays them back.
//   the postcard   a click turns it over: a few lines from the journey on
//                  its back; another turns it back
//   the label      a click sets the little train off along the bar (another
//                  stops it)
Item {
    id: root
    anchors.fill: parent

    readonly property url dir: Qt.resolvedUrl("../../assets/flavours/" + Flavour.theme + "/")

    // ---------------------------------------------------------------- the postcard
    DeskCard {
        id: postcard
        name: "postcard"
        order: 3
        width: 340
        height: 226
        homeX: 58
        homeY: root.height - height - 64

        Item {
            id: card
            width: postcard.width
            height: postcard.height
            rotation: -3.5
            property bool back: false
            property real turn: back ? 1 : 0
            Behavior on turn { NumberAnimation { duration: Theme.dur(560); easing.type: Easing.InOutCubic } }
            // turned about its upright middle; past half way, its back shows
            transform: Rotation {
                origin.x: card.width / 2
                origin.y: card.height / 2
                axis { x: 0; y: 1; z: 0 }
                angle: card.turn * 180
            }

            Image {
                anchors.fill: parent
                visible: card.turn < 0.5
                source: root.dir + "postcard.png"
                sourceSize: Qt.size(card.width * 2, card.height * 2)
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
                asynchronous: true
            }

            // its back: cream card, a dividing line, a few lines of ink
            Item {
                anchors.fill: parent
                anchors.margins: 6
                visible: card.turn >= 0.5
                transform: Rotation {
                    origin.x: (card.width - 12) / 2
                    axis { x: 0; y: 1; z: 0 }
                    angle: 180
                }
                Rectangle {
                    anchors.fill: parent
                    radius: 3
                    color: "#ece3d0"
                    border.width: 1
                    border.color: "#cbbd9f"
                }
                Text {
                    x: 14; y: 8
                    text: "CARTE POSTALE"
                    font.family: Theme.typewriter
                    font.pixelSize: 10
                    font.letterSpacing: 2
                    color: "#7b6f60"
                }
                Rectangle { x: parent.width * 0.56; y: 30; width: 1; height: parent.height - 44; color: "#b9ab8e" }
                Text {
                    x: 14; y: 30
                    width: parent.width * 0.56 - 24
                    wrapMode: Text.WordWrap
                    lineHeight: 0.92
                    font.family: Theme.script
                    font.pixelSize: 15
                    color: "#2f3550"
                    text: "Dearest M., — arrived at dawn after the long night over the Alps. The mountains were silver under the moon, and the tea in the dining car never went cold. Venice is all pink light and water. Wish you were here.\n— A."
                }
                Column {
                    x: parent.width * 0.6; y: parent.height * 0.42
                    width: parent.width * 0.36
                    spacing: 14
                    Repeater {
                        model: ["Mlle M. Holmgren", "7 Lindengasse", "Wien, Autriche"]
                        Column {
                            required property string modelData
                            width: parent.width
                            Text { text: modelData; font.family: Theme.script; font.pixelSize: 14; color: "#2f3550" }
                            Rectangle { width: parent.width; height: 1; color: "#b9ab8e" }
                        }
                    }
                }
                // the stamp's square, faded where it was
                Rectangle {
                    anchors.right: parent.right; anchors.top: parent.top
                    anchors.rightMargin: 12; anchors.topMargin: 10
                    width: 30; height: 36
                    color: "transparent"
                    border.width: 1
                    border.color: "#b9ab8e"
                }
            }

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Theme.shadow
                blurMax: 24
                shadowBlur: 0.35 + 0.25 * postcard.held
                shadowVerticalOffset: 3 + 5 * postcard.held
                shadowHorizontalOffset: 2 + 2 * postcard.held
                shadowOpacity: 0.85
            }

            TapHandler { onTapped: card.back = !card.back }
        }
    }

    // ---------------------------------------------------------------- the departures board
    DeskCard {
        id: departures
        name: "departures"
        order: 5
        width: 560
        height: 162
        homeX: Math.round(root.width * 0.235)
        homeY: 30
        Departures { width: departures.width; height: departures.height }
    }

    // ---------------------------------------------------------------- the night's journey
    DeskCard {
        id: journey
        name: "journey"
        order: 6
        width: 680
        height: 124
        homeX: Math.round(root.width * 0.37)
        homeY: root.height - height - 30
        JourneyLine { width: journey.width; height: journey.height }
    }

    // ---------------------------------------------------------------- the luggage label
    DeskCard {
        id: label
        name: "label"
        order: 4
        width: 300
        height: 113
        homeX: 72
        homeY: 46

        Item {
            id: tag
            width: label.width
            height: label.height
            rotation: 2.5
            // pressed: a little hop, and the train sets off
            property real hop: 0
            transform: Translate { y: -4 * tag.hop }
            SequentialAnimation {
                id: hopping
                NumberAnimation { target: tag; property: "hop"; to: 1; duration: Theme.dur(110); easing.type: Easing.OutQuad }
                NumberAnimation { target: tag; property: "hop"; to: 0; duration: Theme.dur(260); easing.type: Easing.OutBounce }
            }
            Image {
                anchors.fill: parent
                source: root.dir + "label.png"
                sourceSize: Qt.size(tag.width * 2, tag.height * 2)
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
                asynchronous: true
            }
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Theme.shadow
                blurMax: 24
                shadowBlur: 0.3 + 0.25 * label.held
                shadowVerticalOffset: 2.5 + 5 * label.held
                shadowHorizontalOffset: 1.5 + 2 * label.held
                shadowOpacity: 0.8
            }
            TapHandler {
                onTapped: { hopping.restart(); Trainset.toggle(); }
            }
        }
    }
}
