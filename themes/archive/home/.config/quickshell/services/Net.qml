pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth

// Wi-Fi (NetworkManager) and Bluetooth (BlueZ) state for the Instrument card.
Singleton {
    id: root

    readonly property bool wifiOn: Networking.wifiEnabled
    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wiredDevice: Networking.devices.values.find(d => d.type === DeviceType.Wired) ?? null
    readonly property bool wired: wiredDevice?.connected ?? false
    readonly property var wifiNetwork: wifiDevice?.networks?.values?.find(n => n.connected) ?? null
    readonly property string ssid: wifiNetwork?.name ?? ""
    readonly property real signal: wifiNetwork?.signalStrength ?? 0
    readonly property bool online: wired || ssid !== ""

    function setWifi(on: bool): void { Networking.wifiEnabled = on; }

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool bluetoothAvailable: adapter !== null
    readonly property bool bluetoothOn: adapter?.enabled ?? false
    readonly property int bluetoothConnected: (adapter?.devices?.values ?? []).filter(d => d.connected).length

    function setBluetooth(on: bool): void { if (adapter) adapter.enabled = on; }
}
