import QtQuick
import Quickshell
import Quickshell.Io
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

    onOpened: { Brightness.refresh(); Icc.refresh(); keys.forceActiveFocus(); }

    IndexCard {
        id: card
        width: 500
        title: "Instruments"
        subtitle: "Reading room."
        number: Clock.pad(Power.percent, 3)
        labelWidth: 124
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

        // the panel's refresh rate: Auto is 120 Hz plugged in, 60 on battery
        DataRow {
            label: "Refresh"
            labelWidth: card.labelWidth
            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                options: ["60 Hz", "120 Hz", "Auto"]
                current: Refresh.choices.indexOf(Refresh.choice)
                onPicked: i => Refresh.set(Refresh.choices[i])
            }
        }

        DataRow {
            label: "Sheet"
            labelWidth: card.labelWidth
            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                options: ["Folio", "Original", "Dark"]
                current: Mode.look
                onPicked: i => Mode.setLook(i)
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
            label: "Lamp"
            labelWidth: card.labelWidth
            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                checked: Lamp.isOn
                onToggled: on => Lamp.set(on)
            }
        }

        // how long away before it dims, locks and turns the screen off (archive-idle)
        DataRow {
            label: "Lock"
            labelWidth: card.labelWidth
            FileView {
                id: idleFile
                path: Settings.stateHome + "/archive/idle"
                watchChanges: true
                onFileChanged: reload()
                printErrors: false
            }
            Toggle {
                readonly property var minutes: ["2", "5", "10", "30", "never"]
                anchors.verticalCenter: parent.verticalCenter
                options: ["2 m", "5 m", "10 m", "30 m", "Never"]
                current: Math.max(0, minutes.indexOf(idleFile.text().trim() || "5"))
                onPicked: i => {
                    Quickshell.execDetached(["archive-idle", minutes[i]]);
                    idleReread.restart();
                }
                Timer { id: idleReread; interval: 400; onTriggered: idleFile.reload() }
            }
        }

        // the screen's colour profile: click for the next, right-click the previous
        DataRow {
            label: "Colour"
            labelWidth: card.labelWidth
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12
                InkText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "‹"
                    color: Theme.faded
                    font.pixelSize: Theme.sizeData
                    visible: Icc.profiles.length > 0
                }
                InkText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Icc.profiles.length > 0 ? 230 : 330
                    text: Icc.profiles.length > 0 ? Icc.name : "Add to ~/.local/share/icc"
                    color: Icc.current === "none" ? Theme.faded : Theme.soft
                    font.pixelSize: Icc.profiles.length > 0 ? Theme.sizeData : Theme.sizeLabel
                    elide: Text.ElideMiddle
                }
                InkText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "›"
                    color: Theme.faded
                    font.pixelSize: Theme.sizeData
                    visible: Icc.profiles.length > 0
                }
            }
            MouseArea {
                anchors.fill: parent
                enabled: Icc.profiles.length > 0
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => Icc.cycle(mouse.button === Qt.RightButton ? -1 : 1)
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
            // nmtui: scan, pick a network, type its password (the connection editor
            // only edits saved ones)
            ArchiveButton { text: "Wi-Fi"; onClicked: { Quickshell.execDetached(["foot", "--title=Wi-Fi", "-e", "nmtui-connect"]); Panels.close(); } }
            ArchiveButton { text: "Devices"; onClicked: { Quickshell.execDetached(["blueman-manager"]); Panels.close(); } }
            ArchiveButton { text: "Machine"; onClicked: { Quickshell.execDetached(["rog-control-center"]); Panels.close(); } }
            ArchiveButton { text: "Keys"; onClicked: Panels.show("keys") }
            // go back to a restore point (archive-snapshot: Timeshift asks which)
            ArchiveButton { text: "Restore"; onClicked: { Quickshell.execDetached(["foot", "--title=Restore points", "-e", "archive-snapshot", "restore"]); Panels.close(); } }
        }
    }
}
