import QtQuick
import qs.services

// The lock screen's clock: a station's split-flap departure board, flat on
// the glass, see-through. The time in large cards; the one departure, your
// desk, with its status (ON TIME at rest, BOARDING when woken, CHECKING,
// HELD for a wrong key, DEPARTED when let in); and what is playing. Every
// card flips to what it has to show, as the real ones do. Drawn at 1920 px
// wide and scaled with the screen (s).
//
//   DepartureBoard { s: ...; now: tick.date; status: "ON TIME" }
Item {
    id: board

    property real s: 1
    property date now: new Date()
    property string status: "ON TIME"

    readonly property color cream: "#f3ead8"
    readonly property color dim: Qt.rgba(0.95, 0.92, 0.85, 0.55)
    readonly property color rust: "#d9703f"
    readonly property color lamp: status === "HELD" ? "#e2674a"
        : status === "DEPARTED" || status === "BOARDING" ? "#8fd18a"
        : status === "CHECKING" ? "#e9c25b" : "#e9a95b"
    readonly property var days: ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
    readonly property var months: ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]

    width: 560 * s
    height: body.implicitHeight + 2 * pad
    readonly property real pad: 22 * s

    // ---- the board's housing: smoked glass, a line inside its edge
    Rectangle {
        anchors.fill: parent
        radius: 12 * board.s
        color: Qt.rgba(0.055, 0.04, 0.035, 0.58)
        border.color: Qt.rgba(1, 0.96, 0.9, 0.16); border.width: 1
        Rectangle {
            anchors.fill: parent; anchors.margins: 5 * board.s
            radius: 8 * board.s; color: "transparent"
            border.color: Qt.rgba(1, 0.96, 0.9, 0.08); border.width: 1
        }
    }

    Column {
        id: body
        x: board.pad; y: board.pad
        width: board.width - 2 * board.pad
        spacing: 12 * board.s

        // DEPARTURES, and today
        Item {
            width: parent.width; height: 24 * board.s
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10 * board.s
                Text {
                    text: "///"; color: board.rust
                    font.family: "Barlow"; font.weight: Font.ExtraBold; font.italic: true; font.pixelSize: 20 * board.s
                }
                Text {
                    text: "DEPARTURES"; color: board.cream
                    font.family: "Barlow"; font.weight: Font.Bold; font.pixelSize: 19 * board.s; font.letterSpacing: 4 * board.s
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "発車案内"; color: board.dim
                    font.pixelSize: 15 * board.s; font.letterSpacing: 2 * board.s
                }
            }
            Text {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                text: board.days[board.now.getDay()] + "  " + board.now.getDate() + " " + board.months[board.now.getMonth()]
                color: board.dim
                font.family: "Barlow"; font.weight: Font.DemiBold; font.pixelSize: 17 * board.s; font.letterSpacing: 3 * board.s
            }
        }

        // the time, in large cards
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 7 * board.s
            component Big: FlapTile { width: 74 * board.s; height: 104 * board.s; size: 86 * board.s; flipMs: 110 }
            Big { ch: Qt.formatTime(board.now, "hh").charAt(0) }
            Big { ch: Qt.formatTime(board.now, "hh").charAt(1) }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 22 * board.s; horizontalAlignment: Text.AlignHCenter
                text: ":"; color: board.cream
                opacity: board.now.getSeconds() % 2 === 0 ? 0.95 : 0.35
                font.family: "Barlow"; font.weight: Font.Bold; font.pixelSize: 70 * board.s
            }
            Big { ch: Qt.formatTime(board.now, "mm").charAt(0) }
            Big { ch: Qt.formatTime(board.now, "mm").charAt(1) }
        }

        // the departures: the headings, your desk, what is playing
        Column {
            id: rows
            width: parent.width
            spacing: 6 * board.s
            readonly property real cell: 14.2 * board.s           // a card
            readonly property real cellH: 22 * board.s
            readonly property real p: cell * 1.12                 // card to card (FlapRow's spacing)
            readonly property real g: cell * 0.48                 // between the columns
            component Head: Text {
                color: board.dim
                font.family: "Barlow"; font.weight: Font.DemiBold; font.pixelSize: 12 * board.s; font.letterSpacing: 2 * board.s
            }
            component Cards: FlapRow { cell: rows.cell; cellHeight: rows.cellH }
            Row {
                Head { text: "TIME"; width: 5 * rows.p + rows.g }
                Head { text: "DESTINATION"; width: 15 * rows.p + rows.g }
                Head { text: "PL"; width: 2 * rows.p + rows.g }
                Head { text: "STATUS" }
            }
            Row {
                spacing: rows.g
                Cards { length: 5; text: Qt.formatTime(board.now, "hh:mm") }
                Cards { length: 15; text: "DESKTOP SESSION" }
                Cards { length: 2; text: "1"; align: Text.AlignHCenter }
                Cards { length: 8; text: board.status }
                // the status lamp
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 9 * board.s; height: width; radius: width / 2
                    color: board.lamp
                    Behavior on color { ColorAnimation { duration: 300 } }
                    SequentialAnimation on opacity {
                        running: board.status === "BOARDING" || board.status === "CHECKING"
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.25; duration: 500 }
                        NumberAnimation { to: 1; duration: 500 }
                    }
                    opacity: 1
                }
            }
            // what is playing (blank cards when nothing is)
            Row {
                spacing: rows.g
                Cards { length: 5; text: Media.active ? (Media.playing ? "PLAY" : "PAUSE") : "" }
                Cards { length: 27; text: Media.active ? Media.title + (Media.artist !== "" ? " - " + Media.artist : "") : "" }
            }
        }
    }
}
