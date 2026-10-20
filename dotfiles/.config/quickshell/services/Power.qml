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

    // watts in (charging) or out (on battery); UPower gives it unsigned
    readonly property real rate: battery?.changeRate ?? 0
    readonly property string rateWord: {
        if (!present || rate < 0.1 || battery.state === UPowerDeviceState.FullyCharged) return "";
        const w = rate < 10 ? rate.toFixed(1) : Math.round(rate);
        return (battery.state === UPowerDeviceState.Charging ? "+" : "−") + w + " W";
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
    // read from power-profiles-daemon over D-Bus as it changes (the G14's
    // fan key included), instead of asking powerprofilesctl every 10 s
    readonly property var profiles: ["power-saver", "balanced", "performance"]
    readonly property var profileWords: ({ "power-saver": "Quiet", "balanced": "Balanced", "performance": "Performance" })
    readonly property string profile: PowerProfiles.profile === PowerProfile.PowerSaver ? "power-saver"
        : PowerProfiles.profile === PowerProfile.Performance ? "performance" : "balanced"

    function setProfile(p: string): void {
        PowerProfiles.profile = p === "power-saver" ? PowerProfile.PowerSaver
            : p === "performance" ? PowerProfile.Performance : PowerProfile.Balanced;
    }
}
