pragma Singleton

import QtQuick
import Quickshell

// Which sheet is open: "", "launcher", "power", "themes". One at a time.
Singleton {
    property string open: ""
    function toggle(name: string): void { open = open === name ? "" : name; }
    function close(): void { open = ""; }
    // where the notifications' pager comes in (the top right)
    property real mailY: 34
    // the pager brought up by hand (Super + N), to look through them
    signal pagerRequested()
}
