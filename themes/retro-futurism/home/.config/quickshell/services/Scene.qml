pragma Singleton

import QtQuick
import Quickshell

// What the lock screen and the desk tell each other, for a smooth handover:
//   locked       the session is locked (the taskbar waits below the screen)
//   unlocked()   the lock has just let go (the taskbar comes up)
//   lockNow()    lock the screen (shell.qml)
//   viewShift    how far the city outside the train's window has gone round
//                (0..1), so the lock screen's last picture of the desk shows
//                it where the desk will
Singleton {
    property bool locked: false
    signal unlocked()
    signal lockNow()                // lock, from anywhere in the shell (the power widget)
    property real viewShift: 0
}
