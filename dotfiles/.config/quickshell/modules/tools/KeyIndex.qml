import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import qs.services
import qs.components

// The Index of Keys (Super + /): every shortcut that has a description, as
// Hyprland has them now (yours in user.lua too), in two columns; type to
// find one. Read from `hyprctl binds -j`; until it answers (or if it gives
// no descriptions), from binds.lua itself.
BarPopup {
    id: popup
    name: "keys"
    side: "middle"
    exclusiveKeys: true

    property var keys: []
    readonly property var found: {
        const q = find.text.trim().toLowerCase();
        if (q === "") return keys;
        return keys.filter(k => (k.keys + " " + k.what).toLowerCase().indexOf(q) >= 0);
    }

    onOpened: {
        find.clear();
        bindsFile.reload();         // at once; Hyprland's own list, when it answers, replaces it
        reader.running = true;
        find.take();
    }

    // the ones without a description of their own
    readonly property var also: [
        { keys: "Super + 1 … 9", what: "Go to desk 1 to 9" },
        { keys: "Super + Shift + 1 … 9", what: "Take the window to desk 1 to 9" },
        { keys: "Super + arrows", what: "The window that way" },
        { keys: "Super + Shift + arrows", what: "Swap the window that way" },
        { keys: "Super + drag", what: "Move a window" },
        { keys: "Super + right-drag", what: "Resize a window" },
        { keys: "Super + wheel", what: "Next / previous desk" },
        { keys: "Power, held", what: "Shut down" },
    ]

    readonly property var names: ({
        "SUPER": "Super", "SHIFT": "Shift", "CTRL": "Ctrl", "CONTROL": "Ctrl", "ALT": "Alt",
        "RETURN": "Enter", "ESCAPE": "Esc", "SPACE": "Space", "TAB": "Tab", "GRAVE": "`",
        "MINUS": "-", "EQUAL": "=", "SLASH": "/", "PERIOD": ".", "COMMA": ",", "PRINT": "PrtSc",
        "BACKSPACE": "Backspace", "PAGE_UP": "PgUp", "PAGE_DOWN": "PgDn", "DELETE": "Del",
        "LEFT": "←", "RIGHT": "→", "UP": "↑", "DOWN": "↓"
    })
    function word(k: string): string {
        const u = k.trim().toUpperCase();
        if (names[u] !== undefined) return names[u];
        return u.length === 1 ? u : k.trim().charAt(0).toUpperCase() + k.trim().slice(1);
    }
    function typed(mods: var, key: string): string {
        return mods.concat([key]).filter(x => x !== "").map(word).join(" + ");
    }
    // the same description under two keys: one row
    function gather(list: var): var {
        const out = [];
        const at = {};
        for (const b of list) {
            if (at[b.what] !== undefined) {
                // (a second key only if both still fit the column)
                const row = out[at[b.what]];
                if (row.keys.indexOf("/") < 0 && (row.keys + " / " + b.keys).length <= 26) row.keys += "  /  " + b.keys;
                continue;
            }
            at[b.what] = out.length;
            out.push({ keys: b.keys, what: b.what });
        }
        return out;
    }

    Process {
        id: reader
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                let all = [];
                try { all = JSON.parse(text); } catch (e) { all = []; }
                const list = [];
                for (const b of all) {
                    if (!b.description) continue;
                    const m = b.modmask ?? 0, mods = [];
                    if (m & 64) mods.push("SUPER");
                    if (m & 4) mods.push("CTRL");
                    if (m & 8) mods.push("ALT");
                    if (m & 1) mods.push("SHIFT");
                    list.push({ keys: popup.typed(mods, b.key ?? ""), what: b.description });
                }
                if (list.length > 0) popup.keys = popup.gather(list).concat(popup.also);
            }
        }
    }
    // the fallback: hl.bind(mod .. " + Space", ..., { description = "..." })
    FileView {
        id: bindsFile
        path: Settings.configHome + "/hypr/archive/binds.lua"
        blockLoading: false
        printErrors: false
        onLoaded: {
            const list = [];
            for (const line of text().split("\n")) {
                const m = line.match(/^\s*hl\.bind\(\s*(mod\s*\.\.\s*)?"([^"]+)".*description\s*=\s*"([^"]+)"/);
                if (!m) continue;
                const parts = m[2].split("+").map(s => s.trim()).filter(s => s !== "");
                if (m[1]) parts.unshift("SUPER");
                list.push({ keys: parts.map(popup.word).join(" + "), what: m[3] });
            }
            popup.keys = popup.gather(list).concat(popup.also);
        }
    }

    IndexCard {
        id: card
        width: 1240
        title: "Index of Keys"
        subtitle: "Super is the key with the window on it."
        number: String(popup.found.length).padStart(3, "0")
        seed: 1414
        lift: 1.5

        SearchLine {
            id: find
            x: Theme.headerPadH
            width: card.width - 2 * Theme.headerPadH
            onKey: e => { if (e.key === Qt.Key_Escape) { Panels.close(); e.accepted = true; } }
        }
        Rule { width: card.width; height: implicitHeight; seed: 1415 }

        Item {
            id: table
            width: card.width
            readonly property int rowH: 30
            readonly property int perColumn: Math.max(1, Math.ceil(popup.found.length / 2))
            readonly property int colW: (width - 2 * Theme.headerPadH) / 2
            height: Math.max(1, perColumn) * rowH + 16

            // the rule between the columns
            Rule {
                visible: popup.found.length > 1
                vertical: true
                x: Theme.headerPadH + table.colW - 10
                y: 8
                height: table.height - 16
                width: implicitWidth
                color: Theme.ruleFaint
                seed: 1416
            }

            Repeater {
                model: popup.found
                Item {
                    id: entry
                    required property var modelData
                    required property int index
                    readonly property int column: Math.floor(index / table.perColumn)
                    x: Theme.headerPadH + column * table.colW + (column ? 8 : 0)
                    y: 8 + (index % table.perColumn) * table.rowH
                    width: table.colW - 20
                    height: table.rowH
                    InkText {
                        id: keysText
                        width: 236
                        anchors.verticalCenter: parent.verticalCenter
                        text: entry.modelData.keys
                        color: Theme.graphite
                        font.pixelSize: Theme.sizeSmall
                        elide: Text.ElideRight
                    }
                    InkText {
                        anchors.left: keysText.right
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: entry.modelData.what
                        color: Theme.soft
                        font.pixelSize: Theme.sizeSmall
                        elide: Text.ElideRight
                    }
                }
            }

            InkText {
                visible: popup.found.length === 0
                x: Theme.headerPadH
                y: 8
                height: table.rowH
                verticalAlignment: Text.AlignVCenter
                text: popup.keys.length === 0 ? "Reading the keys." : "No key does that."
                color: Theme.faded
            }
        }
    }
}
