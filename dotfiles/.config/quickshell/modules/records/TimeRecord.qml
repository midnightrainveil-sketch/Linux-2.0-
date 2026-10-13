import QtQuick
import Qt5Compat.GraphicalEffects
import qs.theme
import qs.services
import qs.components

// Time Record, laid out to the reference card (485 x 323):
//   header band with subtitle, rule at 58
//   tall typewriter clock "14 : 26" | vertical rule | watercolour sprig
//   rule, then a three-row table with an empty column on the right
IndexCard {
    id: card

    title: Settings.archiveName
    subtitle: "Time Record."
    number: Clock.timeRecordNo
    labelWidth: 112
    seed: 101
    implicitHeight: 323

    // One tall numeral: Courier Prime Bold stretched upright like the
    // reference's condensed typewriter figures. The old digit fades out and
    // the new one types in (120 ms).
    component Digit: Item {
        id: digit
        property string value: "0"
        property string shown: value
        readonly property real em: Theme.sizeClock
        width: em * 0.6
        height: em * 0.592 * Theme.clockStretch

        InkText {
            id: face
            y: -(0.782 - 0.592) * digit.em * Theme.clockStretch
            text: digit.shown
            color: Theme.soft
            font.pixelSize: digit.em
            spread: 1.6
            transform: Scale { yScale: Theme.clockStretch }
        }

        onValueChanged: swap.restart()
        SequentialAnimation {
            id: swap
            NumberAnimation { target: face; property: "opacity"; to: 0; duration: Theme.durDigit / 2 }
            ScriptAction { script: digit.shown = digit.value }
            NumberAnimation { target: face; property: "opacity"; to: 1; duration: Theme.durDigit / 2 }
        }
    }

    // ---- clock band (card y 58 .. 197)
    Item {
        width: card.width
        height: 139

        Row {
            id: clock
            x: 37
            y: 39
            // typed with a worn ribbon: graphite, not black
            opacity: 0.9
            Digit { value: Clock.hours.charAt(0) }
            Digit { value: Clock.hours.charAt(1) }
            // the colon: two round dots, set apart like "14 : 26"
            Item {
                width: 72
                height: parent.height
                Repeater {
                    model: 2
                    Rectangle {
                        required property int index
                        width: 11; height: 11; radius: 5.5
                        color: Theme.soft
                        antialiasing: true
                        x: parent.width / 2 - width / 2
                        y: index === 0 ? parent.height * 0.32 - 5 : parent.height * 0.86 - 5
                    }
                }
            }
            Digit { value: Clock.minutes.charAt(0) }
            Digit { value: Clock.minutes.charAt(1) }
        }

        Rule {
            vertical: true
            x: 375
            y: 29
            height: 97
            width: implicitWidth
            seed: 104
        }

        // the archive's sprig, a watercolour wash
        Item {
            x: 404
            y: 22
            width: 54
            height: 110
            Image {
                id: sprigImage
                anchors.fill: parent
                source: Qt.resolvedUrl("../../assets/sprig-wash.png")
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
                visible: false
            }
            ColorOverlay {
                anchors.fill: parent
                source: sprigImage
                color: Theme.sprigInk
            }
        }
    }

    // ---- table (card y 197 .. 323), an empty column right of x 382
    Item {
        width: card.width
        height: 126

        Rule {
            x: Theme.ruleInset
            width: parent.width - 2 * Theme.ruleInset
            y: -height / 2
            height: implicitHeight
            seed: 105
        }
        Rule {
            vertical: true
            x: 382
            y: 0
            height: parent.height - 4
            width: implicitWidth
            seed: 106
        }

        Column {
            y: 2
            width: parent.width
            DataRow { label: "Date"; value: Clock.longDate; labelWidth: card.labelWidth; ruleRight: 382 }
            DataRow { label: "Day"; value: "Week " + Clock.week; labelWidth: card.labelWidth; ruleRight: 382 }
            DataRow {
                label: "Location"
                value: Clock.coordinates(Settings.latitude, Settings.longitude)
                labelWidth: card.labelWidth
                ruleRight: 382
                last: true
                rowHeight: 40
            }
        }
    }
}
