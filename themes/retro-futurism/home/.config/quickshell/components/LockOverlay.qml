import QtQuick
import QtQuick.Effects
import qs.services

// The lock screen at rest: a flat, see-through layer on the glass, over the
// room: the date and the time large at the top, and along the foot a
// smoked strip with what the machine is doing (what is playing, the
// notifications waiting, Wi-Fi, the battery) and how to get in. Drawn at
// 1920 px wide and scaled with the screen (s).
//
//   LockOverlay { anchors.fill: parent; s: ...; now: tick.date }
Item {
    id: hud

    property real s: 1
    property date now: new Date()

    readonly property color ink: "#fff6ea"                 // a warm white
    readonly property color dim: Qt.rgba(1, 0.965, 0.92, 0.62)
    readonly property string face: "Barlow"
    readonly property string mono: "JetBrains Mono"
    readonly property var days: ["SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"]
    readonly property var months: ["JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY",
                                   "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"]

    // ---- shade at the top and the foot, so the white reads on the picture
    Rectangle {
        width: parent.width; height: parent.height * 0.42
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0.06, 0.035, 0.02, 0.55) }
            GradientStop { position: 1.0; color: Qt.rgba(0.06, 0.035, 0.02, 0) }
        }
    }
    Rectangle {
        y: parent.height * 0.72; width: parent.width; height: parent.height * 0.28
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0.06, 0.035, 0.02, 0) }
            GradientStop { position: 1.0; color: Qt.rgba(0.06, 0.035, 0.02, 0.5) }
        }
    }

    // ---- the date and the time: the time cut by the slices of a retro
    // sunset through its lower half (as the poster's sun), the theme's ///
    // either side of the date, a tape's three stripes under it all
    readonly property color rust: "#d9703f"
    readonly property color amber: "#e9a95b"
    Item {
        id: top
        anchors.fill: parent
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0.05, 0.02, 0, 0.55)
            shadowBlur: 0.6
            shadowVerticalOffset: 2 * hud.s
        }
        Row {
            id: date
            anchors.horizontalCenter: parent.horizontalCenter
            y: 64 * hud.s
            spacing: 16 * hud.s
            component Slashes: Text {
                text: "///"; color: hud.rust
                font.family: hud.face; font.weight: Font.ExtraBold; font.italic: true
                font.pixelSize: 22 * hud.s; font.letterSpacing: -1 * hud.s
            }
            Slashes { anchors.verticalCenter: parent.verticalCenter }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: hud.days[hud.now.getDay()] + "  \u00b7  " + hud.now.getDate() + " " + hud.months[hud.now.getMonth()]
                color: hud.dim
                font.family: hud.face; font.weight: Font.DemiBold
                font.pixelSize: 22 * hud.s; font.letterSpacing: 6 * hud.s
            }
            Slashes { anchors.verticalCenter: parent.verticalCenter }
        }
        Item {
            id: clock
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: date.bottom; anchors.topMargin: -12 * hud.s
            width: time.implicitWidth; height: time.implicitHeight
            Text {
                id: time
                visible: false
                layer.enabled: true
                text: Qt.formatTime(hud.now, "hh:mm")
                color: hud.ink
                font.family: hud.face; font.weight: Font.Medium; font.italic: true
                font.pixelSize: 168 * hud.s; font.letterSpacing: -2 * hud.s
            }
            // the slices: gaps through the figures' lower half, wider lower down
            Item {
                id: slices
                anchors.fill: parent
                visible: false
                layer.enabled: true
                readonly property real fig: time.font.pixelSize * 0.7     // the figures' height
                readonly property real top0: time.baselineOffset - fig
                readonly property var gaps: [[0.56, 0.022], [0.70, 0.032], [0.84, 0.045]]
                Repeater {
                    model: 4
                    Rectangle {
                        required property int index
                        readonly property real from: index === 0 ? 0
                            : slices.top0 + slices.fig * (slices.gaps[index - 1][0] + slices.gaps[index - 1][1])
                        readonly property real to: index === 3 ? slices.height
                            : slices.top0 + slices.fig * slices.gaps[index][0]
                        y: from; width: slices.width; height: Math.max(0, to - from)
                        color: "white"
                    }
                }
            }
            MultiEffect {
                anchors.fill: parent
                source: time
                maskEnabled: true
                maskSource: slices
                opacity: 0.9
            }
        }
        // a tape's three stripes
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: clock.bottom; anchors.topMargin: -6 * hud.s
            spacing: 3 * hud.s
            Repeater {
                model: [hud.rust, hud.amber, hud.ink]
                Rectangle {
                    required property var modelData
                    required property int index
                    x: index * 6 * hud.s
                    width: 150 * hud.s; height: 3.5 * hud.s; radius: height / 2
                    color: modelData; opacity: 0.85
                }
            }
        }
    }

    // ---- the strip along the foot
    Rectangle {
        id: strip
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: 48 * hud.s
        width: Math.min(parent.width - 96 * hud.s, row.implicitWidth + 64 * hud.s)
        height: 60 * hud.s
        radius: 10 * hud.s
        color: Qt.rgba(0.08, 0.05, 0.035, 0.42)
        border.color: Qt.rgba(1, 0.96, 0.9, 0.18); border.width: 1
        // an inner line, as a tape deck's panel has
        Rectangle {
            anchors.fill: parent; anchors.margins: 4 * hud.s
            radius: 7 * hud.s
            color: "transparent"
            border.color: Qt.rgba(1, 0.96, 0.9, 0.09); border.width: 1
        }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 26 * hud.s

            // the brand, as on the taskbar
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8 * hud.s
                Text {
                    text: "///"; color: hud.rust
                    font.family: hud.face; font.weight: Font.ExtraBold; font.italic: true; font.pixelSize: 20 * hud.s
                }
                Text {
                    text: "MAGNETIC 88"; color: hud.ink
                    font.family: hud.face; font.weight: Font.ExtraBold; font.italic: true
                    font.pixelSize: 19 * hud.s; font.letterSpacing: 3 * hud.s
                }
            }
            Sep {}

            // how to get in
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12 * hud.s
                // a padlock, drawn
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18 * hud.s; height: 22 * hud.s
                    Rectangle {
                        x: 3.5 * hud.s; width: 11 * hud.s; height: 14 * hud.s; radius: 5.5 * hud.s
                        color: "transparent"; border.color: hud.ink; border.width: 2 * hud.s
                    }
                    Rectangle { y: 9 * hud.s; width: parent.width; height: 13 * hud.s; radius: 2.5 * hud.s; color: hud.ink }
                }
                Text {
                    id: hint
                    anchors.verticalCenter: parent.verticalCenter
                    text: "PRESS ANY KEY TO UNLOCK"; color: hud.ink
                    font.family: hud.face; font.weight: Font.DemiBold
                    font.pixelSize: 20 * hud.s; font.letterSpacing: 3.5 * hud.s
                    SequentialAnimation on opacity {
                        running: hud.visible; loops: Animation.Infinite
                        NumberAnimation { to: 0.45; duration: 1400; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: 1400; easing.type: Easing.InOutSine }
                    }
                }
            }

            component Sep: Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1; height: 26 * hud.s; color: Qt.rgba(1, 0.96, 0.9, 0.25)
            }

            // what is playing
            Sep { visible: Media.active }
            Row {
                visible: Media.active
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10 * hud.s
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: Media.playing ? "play" : "pause"; size: 18 * hud.s; color: hud.ink; weight: 2
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, 420 * hud.s); elide: Text.ElideRight
                    text: Media.title + (Media.artist !== "" ? "  ·  " + Media.artist : "")
                    color: hud.dim
                    font.family: hud.face; font.weight: Font.Medium; font.pixelSize: 20 * hud.s
                }
            }

            // the notifications waiting
            Sep { visible: Notifs.count > 0 }
            Row {
                visible: Notifs.count > 0
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8 * hud.s
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "bell"; size: 18 * hud.s; color: hud.ink; weight: 2
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Notifs.count; color: hud.dim
                    font.family: hud.face; font.weight: Font.DemiBold; font.pixelSize: 20 * hud.s
                }
            }

            // Wi-Fi and the battery
            Sep { visible: Net.wifiOn || Net.wired || Power.present }
            Row {
                visible: Net.wifiOn || Net.wired
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3 * hud.s
                Repeater {
                    model: 4
                    Rectangle {
                        required property int index
                        anchors.bottom: parent.bottom
                        width: 4 * hud.s; height: (6 + index * 4) * hud.s; radius: 1
                        color: Net.wired || (Net.online && Net.signal * 4 > index + 0.25) ? hud.ink : Qt.rgba(1, 0.96, 0.9, 0.28)
                    }
                }
            }
            Row {
                visible: Power.present
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8 * hud.s
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 30 * hud.s; height: 15 * hud.s
                    Rectangle {
                        width: 27 * hud.s; height: parent.height; radius: 3.5 * hud.s
                        color: "transparent"; border.color: hud.ink; border.width: 1.6 * hud.s
                        Rectangle {
                            x: 3 * hud.s; y: 3 * hud.s; height: parent.height - 6 * hud.s; radius: 1.5 * hud.s
                            width: Math.max(0, (parent.width - 6 * hud.s) * Power.percent / 100)
                            color: Power.charging ? "#8fd18a" : hud.ink
                        }
                    }
                    Rectangle { x: 27.5 * hud.s; y: 4.5 * hud.s; width: 2.5 * hud.s; height: 6 * hud.s; radius: 1; color: hud.ink }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Power.percent + "%"; color: hud.dim
                    font.family: hud.face; font.weight: Font.DemiBold; font.pixelSize: 20 * hud.s
                }
            }
        }
    }
}
