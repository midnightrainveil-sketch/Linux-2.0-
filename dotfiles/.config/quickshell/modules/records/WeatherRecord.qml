import QtQuick
import qs.theme
import qs.services
import qs.components

// Meteorological Observation: pencil-shaded weather sketch, temperature and
// condition on the left; a small typed table on the right.
// No. = air pressure in hPa.
IndexCard {
    id: card

    title: "Meteorological Observation"
    number: Weather.ready ? String(Weather.pressure) : "----"
    footerLabel: "Location"
    footerValue: Settings.placeName + (Settings.placeCountry && Settings.placeCountry !== Settings.placeName ? ", " + Settings.placeCountry : "")
    labelWidth: 104
    seed: 202

    Item {
        width: parent.width
        height: 112

        Row {
            anchors.left: parent.left
            anchors.leftMargin: Theme.cardPad + 4
            anchors.verticalCenter: parent.verticalCenter
            spacing: 18

            InkIcon {
                group: "weather"
                name: Weather.icon
                size: 60
                color: Theme.graphite
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                InkText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Weather.ready ? Math.round(Weather.temperature) + "°C" : "--°C"
                    color: Theme.graphite
                    font.pixelSize: 30
                    font.bold: true
                }
                InkText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Weather.ready ? Weather.condition : "Awaiting reading."
                    color: Theme.soft
                    font.pixelSize: Theme.sizeData + 1
                }
            }
        }

        Rule {
            id: split
            vertical: true
            x: parent.width * 0.5
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: 2
            width: implicitWidth
            seed: 203
        }

        Grid {
            anchors.left: split.right
            anchors.leftMargin: Theme.headerPadH
            anchors.verticalCenter: parent.verticalCenter
            columns: 2
            columnSpacing: 12
            rowSpacing: 7

            InkText { text: "Feels like"; color: Theme.faded; font.pixelSize: Theme.sizeLabel }
            InkText { text: Weather.ready ? Math.round(Weather.feelsLike) + "°C" : "--"; font.pixelSize: Theme.sizeLabel }
            InkText { text: "Humidity"; color: Theme.faded; font.pixelSize: Theme.sizeLabel }
            InkText { text: Weather.ready ? Weather.humidity + "%" : "--"; font.pixelSize: Theme.sizeLabel }
            InkText { text: "Wind"; color: Theme.faded; font.pixelSize: Theme.sizeLabel }
            InkText { text: Weather.ready ? Math.round(Weather.windSpeed) + " km/h " + Weather.windCompass : "--"; font.pixelSize: Theme.sizeLabel }
            InkText { text: "Pressure"; color: Theme.faded; font.pixelSize: Theme.sizeLabel }
            InkText { text: Weather.ready ? Weather.pressure + " hPa" : "--"; font.pixelSize: Theme.sizeLabel }
        }
    }
}
