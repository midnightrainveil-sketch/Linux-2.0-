import QtQuick
import Quickshell
import qs.theme
import qs.services
import qs.components

// Instrument card (quick settings): rises from the bar's status marks.
// A data table of Wi-Fi, Bluetooth, battery and power profile, toggles as
// circled ON  OFF, and ruler sliders for volume and brightness.
BarPopup {
    id: popup
    name: "instrument"
    side: "right"

    onOpened: { Brightness.refresh(); keys.forceActiveFocus(); }

    IndexCard {
        id: card
        width: 420
        title: "Instruments"
        subtitle: "Settings of the reading room."
        number: Clock.pad(Power.percent, 3)
        labelWidth: 104
        seed: 606
        lift: 1.4

        Item {
            id: keys
            width: 1; height: 0
            focus: true
            Keys.onEscapePressed: Panels.close()
        }

        DataRow {
            label: "Wi-Fi"
            labelWidth: card.labelWidth
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12
                Toggle { checked: Net.wifiOn; onToggled: on => Net.setWifi(on) }
                InkText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Net.wired ? "wired" : Net.ssid
                    color: Theme.faded
                    font.pixelSize: Theme.sizeLabel
                    width: 110
                    elide: Text.ElideRight
                }
            }
        }

        DataRow {
            label: "Bluetooth"
            labelWidth: card.labelWidth
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12
                Toggle { checked: Net.bluetoothOn; available: Net.bluetoothAvailable; onToggled: on => Net.setBluetooth(on) }
                InkText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Net.bluetoothConnected > 0
                    text: Net.bluetoothConnected + " linked"
                    color: Theme.faded
                    font.pixelSize: Theme.sizeLabel
                }
            }
        }

        DataRow {
            label: "Battery"
            labelWidth: card.labelWidth
            value: Power.present ? Power.percent + "%  " + Power.stateWord + (Power.remaining ? ", " + Power.remaining : "") + "." : "On mains."
            valueColor: Power.low ? Theme.madder : Theme.soft
        }

        DataRow {
            label: "Profile"
            labelWidth: card.labelWidth
            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                options: ["Quiet", "Balanced", "Perf."]
                current: Power.profiles.indexOf(Power.profile)
                onPicked: i => Power.setProfile(Power.profiles[i])
            }
        }

        DataRow {
            label: "Sheet"
            labelWidth: card.labelWidth
            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                options: ["Day", "Night"]
                current: Mode.isNight ? 1 : 0
                onPicked: i => Mode.set(i === 1 ? "night" : "day")
            }
        }

        DataRow {
            label: "Grain"
            labelWidth: card.labelWidth
            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                checked: Mode.grain
                onToggled: on => Mode.setGrain(on)
            }
        }

        DataRow {
            label: "Volume"
            labelWidth: card.labelWidth
            rowHeight: 50
            RulerSlider {
                anchors.left: parent.left
                anchors.right: volNo.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                value: Audio.volume
                onMoved: v => Audio.setVolume(v)
            }
            InkText {
                id: volNo
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 52
                text: Audio.muted ? "Mute" : "No. " + Audio.percent
                color: Audio.muted ? Theme.faded : Theme.soft
                font.pixelSize: Theme.sizeLabel
                MouseArea { anchors.fill: parent; onClicked: Audio.toggleMute() }
            }
        }

        DataRow {
            label: "Light"
            labelWidth: card.labelWidth
            rowHeight: 50
            last: true
            RulerSlider {
                anchors.left: parent.left
                anchors.right: briNo.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                value: Brightness.percent / 100
                onMoved: v => Brightness.set(Math.round(v * 100))
            }
            InkText {
                id: briNo
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 52
                text: "No. " + Brightness.percent
                font.pixelSize: Theme.sizeLabel
            }
        }

        Rule { width: parent.width; height: implicitHeight; seed: 607 }

        Flow {
            width: parent.width
            padding: Theme.headerPadH
            spacing: 10
            ArchiveButton { text: "Mixer"; onClicked: { Quickshell.execDetached(["pavucontrol"]); Panels.close(); } }
            ArchiveButton { text: "Networks"; onClicked: { Quickshell.execDetached(["nm-connection-editor"]); Panels.close(); } }
            ArchiveButton { text: "Devices"; onClicked: { Quickshell.execDetached(["blueman-manager"]); Panels.close(); } }
            ArchiveButton { text: "Machine"; onClicked: { Quickshell.execDetached(["rog-control-center"]); Panels.close(); } }
        }
    }
}
