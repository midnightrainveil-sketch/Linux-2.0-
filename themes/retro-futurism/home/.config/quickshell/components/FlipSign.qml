import QtQuick

// A small steel sign on two hinges, as the machines hang in an empty place:
// a cream-enamelled steel plate, screwed, with a black enamel field and its
// word stamped in. It swings down into view when shown (and a little past,
// and back), and folds up out of it when not.
//
//   FlipSign { shown: !held; text: "NO TAPE"; width: 300; height: 70 }
//
// Its top edge is the hinge line: place it there.
Item {
    id: sign

    property bool shown: false
    property string text: ""
    property real lampLevel: 1                 // the small lamp beside the word, 0..1
    property color lamp: "#ff9a2e"

    // 0 folded up (edge on), 1 hanging
    property real open: shown ? 1 : 0
    Behavior on open {
        NumberAnimation {
            duration: sign.shown ? 520 : 200
            easing.type: sign.shown ? Easing.OutBack : Easing.InCubic
            easing.overshoot: 2.6
        }
    }
    visible: open > 0.01

    // the hinges' bar, fixed
    Rectangle {
        x: sign.width * 0.18 - 4; y: -7; width: sign.width * 0.64 + 8; height: 6; radius: 3
        gradient: Gradient {
            GradientStop { position: 0; color: "#b7b0a3" }
            GradientStop { position: 1; color: "#5c574f" }
        }
    }

    Item {
        id: plate
        width: sign.width; height: sign.height
        transform: Rotation {
            origin.x: plate.width / 2; origin.y: 0
            axis { x: 1; y: 0; z: 0 }
            angle: (1 - sign.open) * 88
        }
        // its shadow on what is behind
        Rectangle {
            x: 3; y: 5; width: parent.width; height: parent.height; radius: 7
            color: "black"; opacity: 0.35 * Math.min(1, sign.open)
        }
        // the hinges' knuckles
        Repeater {
            model: 2
            Rectangle {
                required property int index
                x: (index === 0 ? sign.width * 0.18 : sign.width * 0.82) - 9; y: -6; width: 18; height: 11; radius: 4
                gradient: Gradient {
                    GradientStop { position: 0; color: "#e9e4d8" }
                    GradientStop { position: 0.5; color: "#a39c8f" }
                    GradientStop { position: 1; color: "#5a554d" }
                }
                border.width: 1; border.color: "#3e3a35"
            }
        }
        // the plate: cream-enamelled steel, its edge rolled
        Rectangle {
            anchors.fill: parent; radius: 7
            border.width: 2; border.color: "#4e4a43"
            gradient: Gradient {
                GradientStop { position: 0; color: "#ece6d8" }
                GradientStop { position: 0.55; color: "#d9d1c0" }
                GradientStop { position: 1; color: "#c2b9a6" }
            }
            Rectangle {
                anchors.fill: parent; anchors.margins: 3; radius: 5
                color: "transparent"
                border.width: 1; border.color: "#fbf8f0"; opacity: 0.7
            }
        }
        // its screws
        Repeater {
            model: 2
            Item {
                required property int index
                readonly property real r: Math.max(4, sign.height * 0.085)
                x: (index === 0 ? sign.height * 0.26 : sign.width - sign.height * 0.26) - r
                y: sign.height / 2 - r
                width: r * 2; height: r * 2
                Rectangle {
                    anchors.fill: parent; radius: width / 2
                    gradient: Gradient {
                        GradientStop { position: 0; color: "#8f897e" }
                        GradientStop { position: 1; color: "#3f3b35" }
                    }
                    border.width: 1; border.color: "#2c2925"
                }
                Rectangle {
                    anchors.centerIn: parent; width: parent.width * 0.75; height: 1.6
                    rotation: 35 + parent.index * 50
                    color: "#24211e"
                }
            }
        }
        // the black enamel field and its word
        Rectangle {
            id: field
            x: sign.height * 0.5; y: sign.height * 0.2
            width: sign.width - sign.height; height: sign.height * 0.6
            radius: 3
            color: "#262523"
            border.width: 1; border.color: "#14130f"
            // the theme's three slashes, in orange, at its left
            Row {
                id: slashes
                x: field.height * 0.35; anchors.verticalCenter: parent.verticalCenter
                spacing: field.height * 0.12
                Repeater {
                    model: 3
                    Rectangle {
                        width: field.height * 0.16; height: field.height * 0.5
                        color: index === 0 ? "#d2643a" : "#c8bfae"
                        required property int index
                        transform: Matrix4x4 { matrix: Qt.matrix4x4(1, -0.45, 0, field.height * 0.11, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
                    }
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                x: slashes.x + slashes.width + field.height * 0.4
                width: parent.width - x - field.height * 0.9
                horizontalAlignment: Text.AlignHCenter
                text: sign.text
                color: "#efe7d4"
                font.family: "Barlow"; font.weight: Font.Bold
                font.pixelSize: Math.round(field.height * 0.5)
                font.letterSpacing: field.height * 0.12
            }
            // a small lamp at its right
            Rectangle {
                readonly property real d: field.height * 0.32
                x: parent.width - field.height * 0.5 - d / 2; anchors.verticalCenter: parent.verticalCenter
                width: d; height: d; radius: d / 2
                color: Qt.rgba(0.35, 0.22, 0.12, 1)
                border.width: 1; border.color: "#0e0d0b"
                Rectangle {
                    anchors.fill: parent; radius: width / 2
                    color: sign.lamp
                    opacity: sign.lampLevel
                }
                Rectangle {
                    anchors.centerIn: parent; width: parent.width * 2.6; height: width; radius: width / 2
                    color: sign.lamp; opacity: 0.22 * sign.lampLevel
                }
            }
        }
    }
}
