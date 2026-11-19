import QtQuick
import Quickshell
import qs.services

// A check of the shell, for when something will not start: run it with
//   ULTRA_CHECK=1 qs -p ~/ultra/themes/retro-futurism/home/.config/quickshell
// and every widget (widgets/index.json), which otherwise loads only when it
// is called, is compiled and made once here; each prints "check: ok <id>" or
// "check: FAILED <id>" and the reason. (The rest of the shell has loaded if
// this runs at all.)
Scope {
    id: check

    Timer {
        interval: 1500
        running: true
        onTriggered: {
            const list = Widgets.list;
            if (list.length === 0) { console.warn("check: FAILED widgets/index.json gave no widgets"); return; }
            let bad = 0;
            for (const w of list) {
                const c = Qt.createComponent(Widgets.source(w.id));
                if (c.status === Component.Error) {
                    bad++;
                    console.warn("check: FAILED " + w.id + ": " + c.errorString());
                    continue;
                }
                const o = c.createObject(null);
                if (!o) { bad++; console.warn("check: FAILED " + w.id + ": could not be made"); continue; }
                o.destroy();
                console.warn("check: ok " + w.id);
            }
            console.warn("check: done, " + (list.length - bad) + " of " + list.length + " widgets load");
        }
    }
}
