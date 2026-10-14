import QtQuick
import qs.theme
import qs.services
import qs.components

// Meteorological Observation, laid out to the reference card (485 x 249):
//   header band, rule at 45
//   pencil cloud | big temperature over the condition | vertical rule |
//   a four-line typed table (labels left, values set to the right)
//   footer: Location | place
// No. = air pressure in hPa.
IndexCard {
    id: card

    title: "Meteorological Observation"
    number: Weather.ready ? String(Weather.pressure) : "----"
    footerLabel: "Location"
    footerValue: Settings.placeName + (Settings.placeCountry && Settings.placeCountry !== Settings.placeName ? ", " + Settings.placeCountry : "")
    labelWidth: 115
    seed: 202
    implicitHeight: 249

    Item {
        width: card.width
        height: 158        // header 45 + 158 = footer rule at 203

        InkIcon {
            group: "weather"
            name: Weather.icon
            x: 16
            y: 26
            size: 115
            color: Theme.soft
        }

        // temperature: typewriter figures stretched a little upright, as
        // much as the clock's and no more
        Item {
            id: temp
            readonly property real stretch: Theme.clockStretch
            x: 155
            width: 82
            height: Math.round(0.592 * Theme.sizeDisplay * stretch)
            y: 57 + (46 - height) / 2
            InkText {
                anchors.horizontalCenter: parent.horizontalCenter
                y: -(0.782 - 0.592) * Theme.sizeDisplay * temp.stretch
                text: Weather.ready ? Math.round(Weather.temperature) + "°C" : "--°C"
                color: Theme.graphite
                font.pixelSize: Theme.sizeDisplay
                spread: 1.0
                transform: Scale { yScale: temp.stretch; origin.x: 0; origin.y: 0 }
            }
        }
        InkText {
            anchors.horizontalCenter: temp.horizontalCenter
            y: 101
            text: Weather.ready ? Weather.condition : "Awaiting."
            color: Theme.soft
            font.pixelSize: 18
        }

        Rule {
            vertical: true
            x: 295
            y: 19
            height: 131
            width: implicitWidth
            seed: 203
        }

        Column {
            x: 314
            y: 22
            width: card.width - x - Theme.ruleInset - 2
            spacing: 0
            Repeater {
                model: [
                    ["Feels like", Weather.ready ? Math.round(Weather.feelsLike) + "°C" : "--"],
                    ["Humidity", Weather.ready ? Weather.humidity + "%" : "--"],
                    ["Wind", Weather.ready ? Math.round(Weather.windSpeed) + " km/h " + Weather.windCompass : "--"],
                    ["Pressure", Weather.ready ? Weather.pressure + " hPa" : "--"]
                ]
                Item {
                    required property var modelData
                    width: parent.width
                    height: 27.5
                    InkText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData[0]
                        color: Theme.labelInk
                        font.pixelSize: Theme.sizeSmall
                    }
                    InkText {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData[1]
                        color: Theme.soft
                        font.pixelSize: Theme.sizeSmall
                    }
                }
            }
        }
    }
}
