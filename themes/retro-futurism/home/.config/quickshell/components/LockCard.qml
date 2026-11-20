import QtQuick
import qs.services

// The lock screen's card at rest: a small e-ink screen in the windows'
// chrome rim (components/ChromePanel.qml), over the room. The time and the
// date, what the machine is doing (battery, Wi-Fi, what is playing, the
// notifications waiting) and how to get in. Drawn at 1920 px wide and
// scaled with the screen (s).
//
//   LockCard { s: surface.width / 1920; now: tick.date }
ChromePanel {
    id: card

    property real s: 1
    property date now: new Date()

    readonly property color ink: "#2a2c2a"
    readonly property color faint: Qt.rgba(0.16, 0.17, 0.16, 0.55)
    readonly property string lcd: "VT323"
    readonly property string plate: "Barlow"
    readonly property var days: ["SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"]
    readonly property var months: ["JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY",
                                   "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"]

    rim: 17 * s
    width: 540 * s
    height: body.implicitHeight + 2 * (rim + 18 * s)

    Column {
        id: body
        width: parent.width
        spacing: 0

        // ---- LOCKED, and the machine's state
        Item {
            width: parent.width; height: 34 * card.s
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10 * card.s
                Text {
                    text: "///"; color: card.ink
                    font.family: card.plate; font.weight: Font.ExtraBold; font.italic: true
                    font.pixelSize: 24 * card.s
                }
                Text {
                    text: "LOCKED"; color: card.ink
                    font.family: card.lcd; font.pixelSize: 34 * card.s; font.letterSpacing: 2 * card.s
                }
            }
            Row {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                spacing: 16 * card.s
                // Wi-Fi: four bars, as many dark as the signal
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3 * card.s
                    visible: Net.wifiOn || Net.wired
                    Repeater {
                        model: 4
                        Rectangle {
                            required property int index
                            anchors.bottom: parent.bottom
                            width: 5 * card.s; height: (7 + index * 5) * card.s
                            color: Net.wired || (Net.online && Net.signal * 4 > index + 0.25) ? card.ink : card.faint
                        }
                    }
                }
                // the battery: its outline, filled as far as it is charged
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6 * card.s
                    visible: Power.present
                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 38 * card.s; height: 18 * card.s
                        Rectangle {
                            width: 35 * card.s; height: parent.height
                            color: "transparent"; border.color: card.ink; border.width: 2 * card.s
                            radius: 3 * card.s
                            Rectangle {
                                x: 4 * card.s; y: 4 * card.s; height: parent.height - 8 * card.s
                                width: Math.max(0, (parent.width - 8 * card.s) * Power.percent / 100)
                                color: card.ink
                            }
                        }
                        Rectangle { x: 35 * card.s; y: 5 * card.s; width: 3 * card.s; height: 8 * card.s; color: card.ink }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: (Power.charging ? "+" : "") + Power.percent + "%"; color: card.ink
                        font.family: card.lcd; font.pixelSize: 30 * card.s
                    }
                }
            }
        }
        Rectangle { width: parent.width; height: 2.5 * card.s; color: card.ink }

        // ---- the time, large, and the date under it
        Item {
            width: parent.width; height: 150 * card.s
            Text {
                id: time
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 4 * card.s
                text: Qt.formatTime(card.now, "hh") + (card.now.getSeconds() % 2 === 0 ? ":" : " ") + Qt.formatTime(card.now, "mm")
                color: card.ink
                font.family: card.lcd; font.pixelSize: 176 * card.s
                // the unlit segments behind, as an LCD has
                Text {
                    z: -1
                    text: "88:88"; color: Qt.rgba(0.16, 0.17, 0.16, 0.07)
                    font: time.font
                }
            }
        }
        Text {
            width: parent.width; horizontalAlignment: Text.AlignHCenter
            text: card.days[card.now.getDay()] + "  " + card.now.getDate() + " " + card.months[card.now.getMonth()]
            color: card.ink
            font.family: card.plate; font.weight: Font.Bold; font.pixelSize: 24 * card.s
            font.letterSpacing: 3 * card.s
        }
        Item { width: 1; height: 10 * card.s }

        // ---- what is playing; the notifications waiting
        Item { width: 1; height: (Media.active || Notifs.count > 0) ? 8 * card.s : 0 }
        Repeater {
            model: [
                { show: Media.active, icon: Media.playing ? "play" : "pause",
                  text: (Media.title + (Media.artist !== "" ? "  -  " + Media.artist : "")).toUpperCase() },
                { show: Notifs.count > 0, icon: "bell",
                  text: Notifs.count + (Notifs.count === 1 ? " NOTIFICATION" : " NOTIFICATIONS") }
            ]
            Item {
                required property var modelData
                visible: modelData.show
                width: body.width; height: visible ? 38 * card.s : 0
                Rectangle { width: parent.width; height: 1.5 * card.s; color: card.faint }
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: modelData.icon; size: 22 * card.s; color: card.ink; weight: 2
                }
                Text {
                    x: 36 * card.s; width: parent.width - x
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.text; elide: Text.ElideRight; color: card.ink
                    font.family: card.lcd; font.pixelSize: 30 * card.s
                }
            }
        }

        // ---- how to get in
        Rectangle { width: parent.width; height: 2.5 * card.s; color: card.ink }
        Item {
            width: parent.width; height: 42 * card.s
            Text {
                id: hint
                anchors.left: parent.left; anchors.bottom: parent.bottom
                text: "PRESS ANY KEY TO UNLOCK"; color: card.ink
                font.family: card.lcd; font.pixelSize: 30 * card.s; font.letterSpacing: 1 * card.s
                SequentialAnimation on opacity {
                    running: card.visible; loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 1100; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 1100; easing.type: Easing.InOutSine }
                }
            }
            Text {
                anchors.right: parent.right; anchors.bottom: parent.bottom
                text: "M88"; color: card.faint
                font.family: card.plate; font.weight: Font.ExtraBold; font.italic: true; font.pixelSize: 22 * card.s
            }
        }
    }
}
