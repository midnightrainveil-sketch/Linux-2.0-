import QtQuick
import qs.theme
import qs.services
import qs.components

// A departures board from Vienna's Südbahnhof, on card, for the top of
// Compartment 19's desk: tonight's trains, ours (21:40 to Venezia, No. 19)
// marked. Each train's remark follows the clock: on time, boarding in the
// quarter hour before it leaves, then departed (until the small hours).
Item {
    id: board
    implicitWidth: 560
    implicitHeight: 162

    readonly property var trains: [
        { t: "21:40", to: "VENEZIA S. LUCIA", via: "via Semmering", pl: "4", ours: true },
        { t: "22:15", to: "TRIESTE C.LE", via: "via Graz", pl: "2", ours: false },
        { t: "22:50", to: "MÜNCHEN HBF", via: "via Salzburg", pl: "7", ours: false },
        { t: "23:05", to: "BUDAPEST KELETI", via: "via Gy\u0151r", pl: "1", ours: false }
    ]
    // minutes since the evening's start (noon), so after midnight still counts as tonight
    function eve(h: int, m: int): int { return ((h + 12) % 24) * 60 + m; }
    readonly property int nowEve: eve(Clock.now.getHours(), Clock.now.getMinutes())
    function remark(t: string): string {
        const d = eve(Number(t.slice(0, 2)), Number(t.slice(3, 5))) - nowEve;
        if (d < -360 || d > 600) return "On time";
        if (d < 0) return "Departed";
        if (d <= 15) return "Boarding";
        return "On time";
    }

    Paper {
        anchors.fill: parent
        seed: 1931
        lift: 0.9
    }

    Column {
        x: 22; y: 14
        width: board.width - 44
        spacing: 6
        Row {
            width: parent.width
            InkText {
                text: "DEPARTURES"
                caps: true
                tracking: 0.18
                font.pixelSize: 15
                font.bold: true
                color: Theme.graphite
            }
            Item { width: 12; height: 1 }
            InkText {
                anchors.baseline: parent.children[0].baseline
                text: "Wien Südbahnhof · Abfahrt"
                font.pixelSize: 12
                font.italic: true
                color: Theme.faded
            }
        }
        Rule { width: parent.width; height: implicitHeight; seed: 1932 }
        Repeater {
            model: board.trains
            Item {
                id: row
                required property var modelData
                width: parent.width
                height: 21
                readonly property string note: board.remark(modelData.t)
                // ours, underlined in madder
                Rectangle {
                    visible: row.modelData.ours
                    x: -6; y: 1
                    width: parent.width + 12; height: parent.height - 2
                    radius: 2
                    color: Qt.rgba(Theme.madder.r, Theme.madder.g, Theme.madder.b, 0.10)
                }
                InkText { x: 0; anchors.verticalCenter: parent.verticalCenter; text: row.modelData.t; font.pixelSize: 14; font.bold: true; color: Theme.graphite }
                InkText { x: 60; anchors.verticalCenter: parent.verticalCenter; text: row.modelData.to; font.pixelSize: 13; color: Theme.graphite }
                InkText { x: 214; anchors.verticalCenter: parent.verticalCenter; text: row.modelData.via; font.pixelSize: 12; font.italic: true; color: Theme.soft }
                InkText { x: 352; anchors.verticalCenter: parent.verticalCenter; text: "Pl. " + row.modelData.pl; font.pixelSize: 12; color: Theme.soft }
                // ours: the compartment, in madder
                InkText { visible: row.modelData.ours; x: 398; anchors.verticalCenter: parent.verticalCenter; text: "Cpt. 19"; font.pixelSize: 11; font.bold: true; color: Theme.madder }
                // the remark, flipping over like a board's flap when it changes
                InkText {
                    id: remarkText
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.note
                    font.pixelSize: 12
                    font.bold: row.note === "Boarding"
                    color: row.note === "Boarding" ? Theme.madder : row.note === "Departed" ? Theme.faded : Theme.soft
                    transform: Scale { id: flap; origin.y: remarkText.height / 2; yScale: 1 }
                    onTextChanged: flip.restart()
                    SequentialAnimation {
                        id: flip
                        NumberAnimation { target: flap; property: "yScale"; to: 0; duration: 90 }
                        NumberAnimation { target: flap; property: "yScale"; to: 1; duration: 140; easing.type: Easing.OutBack }
                    }
                }
            }
        }
    }
}
