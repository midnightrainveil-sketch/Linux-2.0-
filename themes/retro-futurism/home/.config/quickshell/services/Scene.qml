pragma Singleton

import QtQuick
import Quickshell

// What the lock screen and the desk tell each other, for a smooth handover:
//   locked       the session is locked (the taskbar waits below the screen)
//   unlocked()   the lock has just let go (the taskbar comes up)
//   viewShift    how far the city outside the train's window has gone round
//                (0..1), so the lock screen's last picture of the desk shows
//                it where the desk will
Singleton {
    property bool locked: false
    signal unlocked()
    property real viewShift: 0
}
