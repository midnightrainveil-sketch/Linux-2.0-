pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root
    readonly property date now: clock.date
    readonly property string time: Qt.formatTime(now, "hh:mm")
    // 11 NOV WED
    readonly property string day: Qt.formatDate(now, "d MMM ddd").toUpperCase()
    SystemClock { id: clock; precision: SystemClock.Minutes }
}
