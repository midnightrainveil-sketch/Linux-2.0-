import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// A widget's own saved state: a small JSON file kept across restarts,
// ~/.local/state/ultra/retro-futurism/widgets/<id>.json.
//
//   store.get("page", 1)        a value, or the fallback
//   store.set("page", 3)        change it (written a moment later)
//   store.data                  all of it (read-only; use set)
QtObject {
    id: store

    required property string widgetId
    property var data: ({})
    property bool ready: false

    function get(key: string, fallback: var): var {
        const v = data[key];
        return v === undefined || v === null ? fallback : v;
    }
    function set(key: string, value: var): void {
        const d = Object.assign({}, data);
        d[key] = value;
        data = d;
        writeLater.restart();
    }

    property FileView file: FileView {
        path: Widgets.stateDir + "/" + store.widgetId + ".json"
        printErrors: false
        onLoaded: {
            try { store.data = JSON.parse(text()); } catch (e) { store.data = {}; }
            store.ready = true;
        }
        onLoadFailed: store.ready = true          // none yet: starts empty
    }
    // a burst of changes is written once
    property Timer writeLater: Timer {
        interval: 400
        onTriggered: store.file.setText(JSON.stringify(store.data, null, 2))
    }
}
