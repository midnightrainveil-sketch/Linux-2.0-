pragma Singleton
import QtQml
QtObject {
    property bool wifiEnabled: true
    property var devices: ({ values: [ { type: 1, connected: true, networks: { values: [ { connected: true, name: "home", signalStrength: 0.8 } ] } } ] })
}
