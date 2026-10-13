pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The plate collection (section 13). ~/.local/share/archive/plates/
//   index.json            ["0001-geranium-pratense", ...]   (written by archive-plate)
//   <id>/meta.json        names, specimen label, tape strips, detail marks
//   <id>/ink.png          the drawing as an alpha mask (no text, no paper)
//   <id>/wash.png         optional: watercolour tint mask for the flowers
//   <id>/silhouette.png   optional: filled shape, used for the cyanotype photogram
// A new plate is shown each day; settings.json "plate" pins one.
Singleton {
    id: root

    readonly property string dir: Settings.dataHome + "/archive/plates/"
    property var index: []
    property var meta: ({})

    readonly property string current: {
        if (Settings.fixedPlate !== "" && index.indexOf(Settings.fixedPlate) >= 0) return Settings.fixedPlate;
        if (index.length === 0) return "";
        return index[Clock.dayOfYear % index.length];
    }
    readonly property string folder: current === "" ? "" : "file://" + dir + current + "/"

    function field(name: string, fallback: var): var {
        return (meta && meta[name] !== undefined) ? meta[name] : fallback;
    }

    readonly property string number:    field("number", "0000")
    readonly property string region:    field("region", "FLORA EUROPAEA")
    readonly property string latin:     field("latin", "")
    readonly property string authority: field("authority", "")
    readonly property string family:    field("family", "")
    readonly property string common:    field("common", "")
    readonly property var label:        field("label", ({}))
    readonly property var tapes:        field("tapes", [])
    readonly property var marks:        field("marks", [])
    readonly property bool hasWash:     field("wash", false)
    readonly property bool hasSilhouette: field("silhouette", false)

    FileView {
        id: indexFile
        path: root.dir + "index.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { root.index = JSON.parse(indexFile.text()); } catch (e) { root.index = []; }
        }
    }

    FileView {
        id: metaFile
        path: root.current === "" ? "" : root.dir + root.current + "/meta.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { root.meta = JSON.parse(metaFile.text()); } catch (e) { root.meta = {}; }
        }
    }
}
