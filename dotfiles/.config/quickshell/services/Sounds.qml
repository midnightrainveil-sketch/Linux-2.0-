pragma Singleton

import QtQuick
import Quickshell

// The archive sound theme (section 12). Files live in
// ~/.local/share/sounds/archive/stereo/<name>.oga and are optional:
// a missing file just means silence.
Singleton {
    id: root

    readonly property string dir: Settings.dataHome + "/sounds/archive/stereo/"

    // event -> freedesktop sound name
    readonly property var names: ({
        login:    "desktop-login",          // unlock / login: drawer slides open
        lock:     "desktop-logout",         // lock: drawer slides shut
        message:  "message-new-instant",    // one soft stamp press
        urgent:   "dialog-warning",         // two firm stamp presses
        capture:  "screen-capture",         // archive camera shutter
        volume:   "audio-volume-change",    // pencil tick
        plug:     "power-plug",             // paper clip
        battery:  "battery-low",            // brass desk bell
        error:    "dialog-error",           // two knuckle taps
        bell:     "bell"                    // the typewriter's bell, on Return
    })

    property double lastVolumeTick: 0

    function play(event: string): void {
        if (!Settings.sounds) return;
        const name = names[event];
        if (!name) return;
        // Volume ticks repeat while a key is held; keep them sparse.
        if (event === "volume") {
            const now = Date.now();
            if (now - lastVolumeTick < 90) return;
            lastVolumeTick = now;
        }
        Quickshell.execDetached(["pw-play", root.dir + name + ".oga"]);
    }
}
