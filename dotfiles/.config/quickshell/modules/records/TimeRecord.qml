import QtQuick
import qs.theme
import qs.services
import qs.components

// Time Record: large typewritten clock "14 : 26" and the sprig, over a table
// of date, week and location. No. = two-digit year + day of the year.
IndexCard {
    id: card

    title: Settings.archiveName
    subtitle: "Time Record."
    number: Clock.timeRecordNo
    labelWidth: 104
    seed: 101

    // One numeral: the old digit fades out, the new one types in (120 ms).
    component Digit: Item {
        id: digit
        property string value: "0"
        property string shown: value
        implicitWidth: metrics.width
        implicitHeight: metrics.height

        TextMetrics { id: metrics; font: face.font; text: "0" }

        InkText {
            id: face
            text: digit.shown
            color: Theme.graphite
            font.pixelSize: Theme.sizeClock
            font.bold: true
            tracking: Theme.trackClock
        }

        onValueChanged: swap.restart()
        SequentialAnimation {
            id: swap
            NumberAnimation { target: face; property: "opacity"; to: 0; duration: Theme.durDigit / 2 }
            ScriptAction { script: digit.shown = digit.value }
            NumberAnimation { target: face; property: "opacity"; to: 1; duration: Theme.durDigit / 2 }
        }
    }

    Item {
        width: parent.width
        height: 104

        Row {
            id: clock
            anchors.left: parent.left
            anchors.leftMargin: Theme.cardPad + 4
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0
            Digit { value: Clock.hours.charAt(0) }
            Digit { value: Clock.hours.charAt(1) }
            // the colon, spaced like "14 : 26" but tighter than a full typewriter space
            InkText {
                text: ":"
                leftPadding: 10
                rightPadding: 10
                color: Theme.graphite
                font.pixelSize: Theme.sizeClock
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -4
            }
            Digit { value: Clock.minutes.charAt(0) }
            Digit { value: Clock.minutes.charAt(1) }
        }

        Rule {
            id: sprigRule
            vertical: true
            anchors.right: sprig.left
            anchors.rightMargin: 18
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: 12
            anchors.bottomMargin: 12
            width: implicitWidth
            seed: 104
        }

        // the signature glyph, inked in the pale watercolour blue
        InkIcon {
            id: sprig
            name: "sprig"
            size: 64
            color: Theme.night > 0.5 ? Theme.accent : Theme.day.wash
            anchors.right: parent.right
            anchors.rightMargin: Theme.cardPad + 14
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Rule { width: parent.width; height: implicitHeight; seed: 105 }

    DataRow { label: "Date"; value: Clock.longDate; labelWidth: card.labelWidth }
    DataRow { label: "Week"; value: "Week " + Clock.week; labelWidth: card.labelWidth }
    DataRow {
        label: "Location"
        value: Clock.coordinates(Settings.latitude, Settings.longitude)
        labelWidth: card.labelWidth
        last: true
    }
    Item { width: 1; height: 4 }
}
