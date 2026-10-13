pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// Battery (UPower) and power profile (power-profiles-daemon, which asusctl
// keeps in sync with the G14's Silent / Balanced / Performance modes).
Singleton {
    id: root

    readonly property UPowerDevice battery: UPower.displayDevice
    readonly property bool present: battery?.isLaptopBattery ?? false
    readonly property int percent: Math.round((battery?.percentage ?? 0) * 100)
    readonly property bool charging: battery?.state === UPowerDeviceState.Charging
                                     || battery?.state === UPowerDeviceState.FullyCharged
                                     || battery?.state === UPowerDeviceState.PendingCharge
    readonly property bool low: present && !charging && percent <= 15
    readonly property string stateWord: {
        if (!present) return "Mains";
        switch (battery.state) {
        case UPowerDeviceState.Charging: return "Charging";
        case UPowerDeviceState.FullyCharged: return "Full";
        case UPowerDeviceState.PendingCharge: return "Held";
        default: return "Discharging";
        }
    }
    readonly property string remaining: {
        const s = charging ? (battery?.timeToFull ?? 0) : (battery?.timeToEmpty ?? 0);
        if (!s) return "";
        const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60);
        return h + " h " + m + " min";
    }

    onChargingChanged: if (present && charging) Sounds.play("plug")

    property bool warned: false
    onLowChanged: {
        if (low && !warned) {
            warned = true;
            Sounds.play("battery");
        } else if (!low) {
            warned = false;
        }
    }

    // ---- power profile
    property string profile: "balanced"
    readonly property var profiles: ["power-saver", "balanced", "performance"]
    readonly property var profileWords: ({ "power-saver": "Quiet", "balanced": "Balanced", "performance": "Performance" })

    function setProfile(p: string): void {
        setter.command = ["powerprofilesctl", "set", p];
        setter.running = true;
    }

    Process { id: setter; onExited: getter.running = true }
    Process {
        id: getter
        command: ["powerprofilesctl", "get"]
        running: true
        stdout: StdioCollector { onStreamFinished: root.profile = text.trim() || root.profile }
    }
    // Profiles can also change from the G14's fan key; re-read now and then.
    Timer { interval: 10000; running: true; repeat: true; onTriggered: getter.running = true }
}
