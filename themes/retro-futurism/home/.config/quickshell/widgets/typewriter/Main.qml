import QtQuick
import Quickshell
import qs.components
import qs.services

// The research station (art/Typewriter.png): the SHINWA RS-2012. A long
// e-ink tablet stands in its slot; a little of it shows for everyday work,
// and it slides up out of the slot, full length, for big work (the machine
// sinking away below). Super + R.
//
//   RESEARCH  type a question, Enter: the best Wikipedia article for it
//             (services/Research.qml, ultra-research), in sections, with
//             its sources beside it; ↑ ↓ Page Up / Down read on
//   SOURCES   the article and those related to it: Enter researches one,
//             O opens it in the browser
//   NOTES     your notes on this session, saved as you write
//   ARCHIVE   every session: Enter opens one, Delete removes it
//   EXPORT    the session (question, article, sources, notes) as Markdown
//             in ~/Documents/Research (Enter, or Ctrl + S anywhere)
//
//   Tab / the keys above the keyboard change view; the round knob (or F11)
//   pulls the tablet out and pushes it back in; Esc pushes it in first.
//   The machine's keys go down as you type, and its carriage runs along
//   with the line.
//
// Placed in the mock-up's own pixels (tools/make_typewriter.py: body.png at
// its 25, 13, tablet.png at 152, 21, carriage.png at 702, 368) and scaled once.
Widget {
    id: self
    widgetId: "typewriter"

    readonly property real k: 0.9
    preferredWidth: 1536 * k
    preferredHeight: 1024 * k

    readonly property color ink: "#2f302f"
    readonly property color grey: "#8b8a86"
    readonly property color light: "#e8e7e2"
    readonly property color sage: "#7c8b69"
    readonly property string serif: "Noto Serif"
    readonly property string sans: "Inter"

    // ---------------------------------------------------------------- state
    property string view: "research"
    readonly property var views: ["research", "sources", "notes", "archive", "export"]
    readonly property var cur: (Research.rev, Research.current)
    property int sourceSel: 0
    property int archiveSel: 0

    function setView(v: string): void {
        if (v === view) { focusView(); return; }
        view = v;
        flash.restart();
        focusView();
    }
    function cycle(d: int): void { setView(views[(views.indexOf(view) + d + views.length) % views.length]); }
    function focusView(): void {
        if (view === "research") ask.forceActiveFocus();
        else if (view === "notes") notesEdit.forceActiveFocus();
        else sink.forceActiveFocus();
    }
    onOpened: focusView()

    // ---- the tablet: in its slot (0) or pulled out (1)
    property real pop: 0
    property real riseR: 0                     // how far its top rises
    property real dropD: 0                     // how far the machine sinks
    property bool out: false
    NumberAnimation on pop { id: popAnim; duration: 620; easing.type: Easing.InOutCubic; running: false }
    function togglePop(): void {
        if (!out) {
            // (as far as the screen allows: its top near the screen's, the
            // slot near its foot)
            const top0 = unit.mapToItem(null, 0, 0).y;
            const per = (unit.mapToItem(null, 0, 100).y - top0) / 100;
            const winH = self.Window.height > 0 ? self.Window.height : 1200;
            riseR = Math.max(0, 21 - (26 - top0) / per);
            dropD = Math.max(0, (winH - 130 - top0) / per - 373);
        }
        out = !out;
        popAnim.to = out ? 1 : 0;
        popAnim.restart();
        press("knob");
    }
    escapeHandler: () => { if (out) { togglePop(); return true; } return false; }

    // ---------------------------------------------------------------- keys
    // the machine's keys (in the picture: x0 y0 x1 y1), each pressed as the
    // keyboard's is
    readonly property var keyBoxes: ({
        "research": [268, 597, 441, 640], "sources": [470, 597, 643, 640], "notes": [665, 597, 826, 640],
        "archive": [846, 597, 1021, 640], "return": [1042, 597, 1206, 640], "knob": [1228, 584, 1281, 637],
        "`": [253, 646, 310, 689], "1": [325, 646, 381, 689], "2": [399, 646, 454, 689], "3": [472, 646, 526, 689],
        "4": [544, 646, 599, 689], "5": [617, 646, 672, 689], "6": [691, 646, 745, 689], "7": [764, 646, 818, 689],
        "8": [837, 646, 891, 689], "9": [911, 646, 966, 689], "0": [985, 646, 1040, 689], "-": [1059, 646, 1114, 689],
        "=": [1133, 646, 1189, 689], "bs": [1208, 646, 1282, 689],
        "q": [262, 691, 352, 733], "w": [367, 691, 431, 733], "e": [440, 691, 503, 733], "r": [514, 691, 576, 733],
        "t": [586, 691, 650, 733], "y": [660, 691, 722, 733], "u": [733, 691, 795, 733], "i": [806, 691, 869, 733],
        "o": [880, 691, 943, 733], "p": [954, 691, 1017, 733], "[": [1028, 691, 1091, 733], "]": [1102, 691, 1165, 733],
        "\\": [1177, 691, 1279, 733],
        "caps": [258, 736, 363, 778], "a": [383, 736, 446, 778], "s": [460, 736, 522, 778], "d": [536, 736, 598, 778],
        "f": [609, 736, 672, 778], "g": [684, 736, 747, 778], "h": [758, 736, 821, 778], "k": [837, 736, 900, 778],
        "l": [913, 736, 976, 778], ";": [989, 736, 1052, 778], "'": [1065, 736, 1128, 778], "enter": [1137, 733, 1282, 812],
        "shift": [250, 781, 390, 823], "z": [415, 781, 485, 823], "x": [495, 781, 565, 823], "c": [570, 781, 640, 823],
        "v": [645, 781, 710, 823], "b": [720, 781, 785, 823], "n": [795, 781, 860, 823], "m": [870, 781, 935, 823],
        ",": [945, 781, 1015, 823], "/": [1020, 781, 1085, 823],
        "fn": [403, 826, 490, 862], "space": [510, 826, 985, 862], "left": [1005, 826, 1070, 862], "right": [1080, 826, 1145, 862]
    })
    readonly property string shifted: "~!@#$%^&*()_+{}|:\"<>?"
    readonly property string plain: "`1234567890-=[]\\;',,/"
    function keyOf(e: var): string {
        switch (e.key) {
        case Qt.Key_Return: case Qt.Key_Enter: return "enter";
        case Qt.Key_Space: return "space";
        case Qt.Key_Backspace: case Qt.Key_Delete: return "bs";
        case Qt.Key_Shift: return "shift";
        case Qt.Key_CapsLock: return "caps";
        case Qt.Key_Left: return "left";
        case Qt.Key_Right: return "right";
        case Qt.Key_Tab: return "q";
        case Qt.Key_Period: case Qt.Key_Greater: return ",";
        }
        const t = (e.text || "").toLowerCase();
        if (t.length !== 1) return "";
        const i = shifted.indexOf(t);
        const c = i >= 0 ? plain.charAt(i) : t;
        return keyBoxes[c] ? c : "";
    }
    property var downKeys: ({})
    property int downRev: 0
    function press(name: string): void {
        if (!name || !keyBoxes[name]) return;
        const d = downKeys; d[name] = Date.now(); downKeys = d; downRev++;
        release.restart();
    }
    Timer {
        id: release; interval: 40; repeat: true
        onTriggered: {
            const now = Date.now(); let any = false;
            const d = self.downKeys;
            for (const k in d) { if (now - d[k] > 120) delete d[k]; else any = true; }
            self.downKeys = d; self.downRev++;
            if (!any) stop();
        }
    }

    // every key, whatever has the keyboard: shown on the machine, and the
    // station's own shortcuts
    function onKey(e: var): void {
        press(keyOf(e));
        const ctrl = e.modifiers & Qt.ControlModifier;
        if (e.key === Qt.Key_F11 || (ctrl && e.key === Qt.Key_Up && !out) || (ctrl && e.key === Qt.Key_Down && out)) { togglePop(); e.accepted = true; return; }
        if (e.key === Qt.Key_Tab) { cycle(1); e.accepted = true; return; }
        if (e.key === Qt.Key_Backtab) { cycle(-1); e.accepted = true; return; }
        if (e.key >= Qt.Key_F1 && e.key <= Qt.Key_F5) { setView(views[e.key - Qt.Key_F1]); e.accepted = true; return; }
        if (ctrl && (e.key === Qt.Key_S || e.key === Qt.Key_E)) { setView("export"); Research.exportCurrent(); e.accepted = true; return; }
    }

    // the carriage: along the line being typed, back with Enter
    property int column: 0
    readonly property real carriageX: 330 + (column % 64) * 12
    function caretColumn(text: string, pos: int): int {
        const before = text.slice(0, pos);
        return pos - (before.lastIndexOf("\n") + 1);
    }

    Item { id: sink; focus: true; Keys.onPressed: e => self.keyOnList(e) }
    function keyOnList(e: var): void {
        onKey(e);
        if (e.accepted) return;
        const n = view === "sources" ? (cur?.sources?.length ?? 0) : view === "archive" ? Research.sessions.length : 0;
        switch (e.key) {
        case Qt.Key_Up: case Qt.Key_Left:
            if (view === "sources") sourceSel = Math.max(0, sourceSel - 1); else if (view === "archive") archiveSel = Math.max(0, archiveSel - 1);
            break;
        case Qt.Key_Down: case Qt.Key_Right:
            if (view === "sources") sourceSel = Math.min(n - 1, sourceSel + 1); else if (view === "archive") archiveSel = Math.min(n - 1, archiveSel + 1);
            break;
        case Qt.Key_Return: case Qt.Key_Enter:
            if (view === "sources" && cur?.sources?.[sourceSel]) researchSource(cur.sources[sourceSel]);
            else if (view === "archive" && Research.sessions[archiveSel]) { Research.open(Research.sessions[archiveSel].id); setView("research"); }
            else if (view === "export") Research.exportCurrent();
            break;
        case Qt.Key_O:
            if (view === "sources" && cur?.sources?.[sourceSel]) Qt.openUrlExternally(cur.sources[sourceSel].url);
            break;
        case Qt.Key_Delete:
            if (view === "archive" && Research.sessions[archiveSel]) { Research.remove(Research.sessions[archiveSel].id); archiveSel = Math.min(archiveSel, Research.sessions.length - 1); }
            break;
        default: return;
        }
        e.accepted = true;
    }
    function researchSource(s: var): void { setView("research"); ask.text = s.title; Research.ask(s.title); column = 0; }

    // ---- an answer arriving: the page turns
    Connections {
        target: Research
        function onBusyChanged() { if (!Research.busy) { flash.restart(); answer.contentY = 0; ask.fresh = true; } }
        function onCurrentIdChanged() { const c = Research.sessions.find(x => x.id === Research.currentId); ask.text = c?.query ?? ""; ask.fresh = true; answer.contentY = 0; notesEdit.load(); }
    }

    // ================================================================ the machine
    Item {
        id: unit
        width: 1536; height: 1024
        scale: self.k
        transformOrigin: Item.TopLeft

        // ------------------------------------------------ the tablet (behind the machine: its foot in the slot)
        Item {
            id: tablet
            x: 152
            y: 21 - self.riseR * self.pop
            width: 1232
            height: 352 + (self.riseR + self.dropD) * self.pop
            readonly property real paperBottom: height - 12
            // (clicks on it stay with it)
            MouseArea { anchors.fill: parent; onDoubleClicked: m => { if (m.y < 82) self.togglePop(); } }
            BorderImage {
                anchors.fill: parent
                source: self.art("tablet.png")
                border { left: 75; right: 72; top: 95; bottom: 22 }
                smooth: true
            }

            component Ink: Text {
                color: self.ink
                font.family: self.sans
                font.pixelSize: 16
                renderType: Text.QtRendering
            }
            component Icon: Image {
                property string name
                property bool lit: false
                source: self.art("icon-" + name + (lit ? "-light" : "-ink") + ".svg")
                sourceSize: Qt.size(96, 96)
                smooth: true; mipmap: true
            }

            // ---- its top line: the station, the session, how far read
            Icon { name: "stack"; x: 104; y: 84; width: 34; height: 34 }
            Ink {
                x: 171; y: 101 - height / 2
                font.pixelSize: 19; font.letterSpacing: 1.2
                text: "RESEARCH STATION / SESSION " + String(self.cur?.n ?? Research.next).padStart(3, "0")
            }
            Ink {
                x: 862 - width; y: 101 - height / 2
                font.pixelSize: 12; font.letterSpacing: 0.4; font.weight: Font.Medium
                text: "RESEARCH PROGRESS"
            }
            Rectangle {
                x: 873; y: 95; width: 210; height: 12; radius: 6
                color: "transparent"; border.width: 1.6; border.color: self.ink
                Rectangle {
                    x: 2.5; y: 2.5; height: 7; radius: 3.5
                    width: Math.max(0, (parent.width - 5) * (self.cur?.read ?? 0))
                    color: self.sage
                    Behavior on width { NumberAnimation { duration: 300 } }
                }
            }
            Ink {
                x: 1096; y: 101 - height / 2
                font.pixelSize: 17
                text: Math.round((self.cur?.read ?? 0) * 100) + " %"
            }

            // ---- the side: its five pages
            Rectangle { x: 98; y: 139; width: 140; height: 1.4; color: self.ink }
            Rectangle { x: 240; y: 131; width: 1.4; height: tablet.paperBottom - 146; color: self.ink }
            Repeater {
                model: [["research", "RESEARCH", "search"], ["sources", "SOURCES", "stack"], ["notes", "NOTES", "notes"],
                        ["archive", "ARCHIVE", "archive"], ["export", "EXPORT", "export"]]
                Item {
                    id: tab
                    required property var modelData
                    required property int index
                    readonly property bool on: self.view === modelData[0]
                    x: 88; y: [153, 192, 225, 261, 295][index]; width: 134; height: 31
                    Rectangle { anchors.fill: parent; radius: 4; color: self.ink; visible: tab.on }
                    Icon { name: tab.modelData[2]; lit: tab.on; x: 12; y: 4; width: 23; height: 23 }
                    Ink {
                        x: 50; y: 15.5 - height / 2
                        font.pixelSize: 14; font.letterSpacing: 0.6
                        color: tab.on ? self.light : self.ink
                        text: tab.modelData[1]
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: self.setView(tab.modelData[0]) }
                }
            }

            // ================================ RESEARCH
            Item {
                id: researchPage
                anchors.fill: parent
                visible: self.view === "research"

                Icon { name: "search"; x: 274; y: 135; width: 30; height: 30 }
                TextInput {
                    id: ask
                    property bool fresh: true
                    x: 320; y: 150 - height / 2; width: 610
                    color: self.ink
                    font.family: self.serif; font.pixelSize: 26; font.weight: Font.Bold
                    clip: true
                    selectionColor: self.ink; selectedTextColor: self.light
                    onCursorPositionChanged: self.column = cursorPosition
                    Keys.onPressed: e => {
                        self.onKey(e);
                        if (e.accepted) return;
                        switch (e.key) {
                        case Qt.Key_Return: case Qt.Key_Enter:
                            Research.ask(text); fresh = true; self.column = 0; e.accepted = true; return;
                        case Qt.Key_Up: answer.flick(0, 900); e.accepted = true; return;
                        case Qt.Key_Down: answer.flick(0, -900); e.accepted = true; return;
                        case Qt.Key_PageUp: answer.contentY = Math.max(0, answer.contentY - answer.height * 0.9); e.accepted = true; return;
                        case Qt.Key_PageDown: answer.contentY = Math.min(Math.max(0, answer.contentHeight - answer.height), answer.contentY + answer.height * 0.9); e.accepted = true; return;
                        }
                        // a new question: typing over the one asked
                        if (fresh && e.text !== "" && e.text.charCodeAt(0) >= 32 && !(e.modifiers & Qt.ControlModifier)) { text = ""; }
                        fresh = false;
                    }
                    Ink {
                        visible: ask.text === ""
                        font: ask.font; color: self.grey
                        text: "Ask a question…"
                    }
                }

                // the answer
                Flickable {
                    id: answer
                    x: 282; y: 175; width: 655
                    height: tablet.paperBottom - 8 - y
                    contentHeight: body.height + 16
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    flickDeceleration: 4000
                    onContentYChanged: if (contentHeight > 0) Research.setRead(Math.min(1, (contentY + height) / contentHeight))
                    onContentHeightChanged: if (contentHeight > 0 && !Research.busy) Research.setRead(contentHeight <= height + 20 ? 1 : (contentY + height) / contentHeight)
                    Column {
                        id: body
                        width: answer.width - 8
                        spacing: 6
                        visible: (self.cur?.sections?.length ?? 0) > 0 && !Research.busy
                        Repeater {
                            model: self.cur?.sections ?? []
                            Column {
                                id: sec
                                required property var modelData
                                required property int index
                                width: body.width
                                spacing: 3
                                Text {
                                    width: parent.width
                                    color: self.ink; renderType: Text.QtRendering
                                    font.family: self.serif; font.pixelSize: 19; font.weight: Font.Bold
                                    wrapMode: Text.Wrap
                                    text: (sec.index + 1) + ". " + sec.modelData.title
                                    topPadding: sec.index ? 6 : 0
                                }
                                Repeater {
                                    model: sec.modelData.paragraphs
                                    Text {
                                        required property string modelData
                                        required property int index
                                        readonly property bool head: modelData.startsWith("§ ")
                                        width: sec.width
                                        color: self.ink; renderType: Text.QtRendering
                                        font.family: self.sans
                                        font.pixelSize: head ? 14 : 16
                                        font.weight: head ? Font.Bold : Font.Normal
                                        font.letterSpacing: head ? 1 : 0
                                        lineHeight: 1.12
                                        wrapMode: Text.Wrap
                                        text: head ? modelData.slice(2).toUpperCase()
                                            : modelData + (sec.index === 0 && index === sec.modelData.paragraphs.length - 1 ? "  [1]" : "")
                                    }
                                }
                            }
                        }
                    }
                }
                // nothing yet, looking, or a failure
                Column {
                    x: 292; y: 190; width: 630
                    spacing: 8
                    visible: Research.busy || !self.cur || (self.cur.error ?? "") !== "" || (self.cur.sections?.length ?? 0) === 0
                    Ink {
                        width: parent.width; wrapMode: Text.Wrap
                        font.pixelSize: 17; font.letterSpacing: 3; font.weight: Font.Medium
                        text: Research.busy ? "SEARCHING THE ARCHIVES" + ".".repeat(1 + Math.floor(dots.n % 3))
                            : (self.cur?.error ?? "") !== "" ? "NO ANSWER" : "READY"
                    }
                    Ink {
                        width: parent.width; wrapMode: Text.Wrap
                        font.pixelSize: 15; color: self.grey
                        text: Research.busy ? "Looking it up on Wikipedia."
                            : (self.cur?.error ?? "") !== "" ? self.cur.error
                            : "Type a question and press Enter. The knob pulls the tablet out for big work."
                    }
                }
                Timer { id: dots; property int n: 0; interval: 400; repeat: true; running: Research.busy; onTriggered: n++ }

                // its sources, beside it
                Rectangle { x: 954; y: 159; width: 1.4; height: tablet.paperBottom - 174; color: self.ink }
                Icon { name: "source"; x: 975; y: 154; width: 22; height: 22 }
                Ink {
                    x: 1006; y: 165 - height / 2
                    font.pixelSize: 15; font.letterSpacing: 0.5
                    text: "SOURCES (" + (self.cur?.sources?.length ?? 0) + ")"
                }
                Column {
                    x: 980; y: 186; width: 180
                    spacing: 9
                    Repeater {
                        model: (self.cur?.sources ?? []).slice(0, Math.max(1, Math.floor((tablet.paperBottom - 196) / 44)))
                        Ink {
                            required property var modelData
                            required property int index
                            width: 180
                            wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight
                            font.pixelSize: 12; lineHeight: 1.05
                            text: "[" + (index + 1) + "] " + modelData.site + ".\n“" + modelData.title + ".”"
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: { self.sourceSel = parent.index; self.setView("sources"); }
                            }
                        }
                    }
                }
            }

            // ================================ the list pages
            component Heading: Ink {
                x: 276; y: 150 - height / 2
                font.family: self.serif; font.pixelSize: 25; font.weight: Font.Bold
            }
            component Hint: Ink {
                x: 276; y: tablet.paperBottom - 24
                font.pixelSize: 11; font.letterSpacing: 2.5; color: self.grey
            }
            component Row2: Item {
                id: r2
                property bool on: false
                property string a
                property string b
                property string c
                signal picked()
                width: 870; height: 48
                Rectangle { anchors.fill: parent; radius: 3; color: "transparent"; border.width: r2.on ? 2 : 0; border.color: self.ink }
                Rectangle { x: 0; y: 6; width: 4; height: 36; color: self.ink; visible: r2.on }
                Ink { x: 16; y: 4; width: 640; elide: Text.ElideRight; font.pixelSize: 16; font.weight: Font.Medium; text: r2.a }
                Ink { x: 16; y: 26; width: 780; elide: Text.ElideRight; font.pixelSize: 13; color: self.grey; text: r2.b }
                Ink { x: 858 - width; y: 6; font.pixelSize: 13; font.letterSpacing: 1.5; color: self.grey; text: r2.c }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: r2.picked() }
            }

            // ---- SOURCES
            Item {
                anchors.fill: parent
                visible: self.view === "sources"
                Heading { text: self.cur?.title ? "Sources: " + self.cur.title : "Sources" }
                ListView {
                    x: 276; y: 178; width: 880; height: tablet.paperBottom - 210
                    clip: true; spacing: 4
                    currentIndex: self.sourceSel
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                    model: self.cur?.sources ?? []
                    delegate: Row2 {
                        required property var modelData
                        required property int index
                        on: index === self.sourceSel
                        a: "[" + (index + 1) + "]  " + modelData.title
                        b: modelData.desc || modelData.url
                        c: modelData.site.toUpperCase()
                        onPicked: self.sourceSel === index ? self.researchSource(modelData) : (self.sourceSel = index)
                    }
                }
                Hint { text: "ENTER  RESEARCH IT  ·  O  OPEN IN THE BROWSER" }
            }

            // ---- NOTES
            Item {
                anchors.fill: parent
                visible: self.view === "notes"
                Heading { text: "Notes" + (self.cur ? ": " + self.cur.query : "") ; width: 870; elide: Text.ElideRight }
                Flickable {
                    id: notesScroll
                    x: 280; y: 178; width: 870; height: tablet.paperBottom - 212
                    contentHeight: notesEdit.contentHeight + 12
                    clip: true; boundsBehavior: Flickable.StopAtBounds
                    TextEdit {
                        id: notesEdit
                        width: notesScroll.width
                        color: self.ink
                        font.family: self.sans; font.pixelSize: 16
                        wrapMode: TextEdit.Wrap
                        selectionColor: self.ink; selectedTextColor: self.light
                        property bool loading: false
                        function load(): void { loading = true; text = (Research.sessions.find(x => x.id === Research.currentId))?.notes ?? ""; loading = false; }
                        Component.onCompleted: load()
                        onTextChanged: if (!loading) saveNotes.restart()
                        onCursorPositionChanged: self.column = self.caretColumn(text, cursorPosition)
                        onCursorRectangleChanged: {
                            const r = cursorRectangle;
                            if (r.y < notesScroll.contentY) notesScroll.contentY = r.y;
                            else if (r.y + r.height > notesScroll.contentY + notesScroll.height) notesScroll.contentY = r.y + r.height - notesScroll.height;
                        }
                        Keys.onPressed: e => self.onKey(e)
                        Ink {
                            visible: notesEdit.text === ""
                            font: notesEdit.font; color: self.grey
                            text: self.cur ? "Write your notes on this session…" : "Ask a question first: notes belong to a session."
                        }
                    }
                }
                Timer { id: saveNotes; interval: 500; onTriggered: Research.setNotes(notesEdit.text) }
                Hint { text: "SAVED AS YOU WRITE  ·  EXPORTED WITH THE SESSION" }
            }

            // ---- ARCHIVE
            Item {
                anchors.fill: parent
                visible: self.view === "archive"
                Heading { text: "Archive" }
                Ink {
                    x: 1150 - width; y: 150 - height / 2
                    font.pixelSize: 14; font.letterSpacing: 2; color: self.grey
                    text: Research.sessions.length + (Research.sessions.length === 1 ? " SESSION" : " SESSIONS")
                }
                ListView {
                    x: 276; y: 178; width: 880; height: tablet.paperBottom - 210
                    clip: true; spacing: 4
                    currentIndex: self.archiveSel
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                    model: Research.sessions
                    delegate: Row2 {
                        required property var modelData
                        required property int index
                        on: index === self.archiveSel
                        a: "SESSION " + String(modelData.n).padStart(3, "0") + "  ·  " + modelData.query
                        b: (modelData.title ? modelData.title : modelData.error || "—") + (modelData.notes ? "  ·  with notes" : "")
                        c: Qt.formatDate(new Date(modelData.created), "dd MMM").toUpperCase() + "  ·  " + Math.round((modelData.read ?? 0) * 100) + "%"
                        onPicked: { if (self.archiveSel === index) { Research.open(modelData.id); self.setView("research"); } else self.archiveSel = index; }
                    }
                }
                Ink {
                    visible: Research.sessions.length === 0
                    x: 280; y: 190; font.pixelSize: 16; color: self.grey
                    text: "No sessions yet."
                }
                Hint { text: "ENTER  OPEN  ·  DELETE  REMOVE" }
            }

            // ---- EXPORT
            Item {
                anchors.fill: parent
                visible: self.view === "export"
                Heading { text: "Export" }
                Column {
                    x: 280; y: 182; width: 860
                    spacing: 10
                    Ink {
                        width: parent.width; wrapMode: Text.Wrap
                        font.pixelSize: 16
                        text: self.cur ? "Session " + String(self.cur.n).padStart(3, "0") + ": “" + self.cur.query + "”, its article, its sources and your notes, as a Markdown file in ~/Documents/Research."
                                       : "Nothing to export yet: ask a question first."
                    }
                    Item {
                        width: 200; height: 40
                        visible: self.cur !== null
                        Rectangle { anchors.fill: parent; radius: 4; color: self.ink }
                        Ink {
                            anchors.centerIn: parent
                            color: self.light; font.pixelSize: 14; font.letterSpacing: 3
                            text: Research.exporting ? "SAVING…" : "EXPORT  ⏎"
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Research.exportCurrent() }
                    }
                    Ink {
                        width: parent.width; wrapMode: Text.WrapAnywhere
                        visible: Research.exported !== ""
                        font.pixelSize: 14; font.letterSpacing: 0.5
                        text: "SAVED  " + Research.exported.replace(/^\/home\/[^/]+/, "~")
                    }
                }
            }

            // ---- an e-ink page turns with a quick dark flash
            Rectangle {
                x: 64; y: 85; width: 1103; height: tablet.paperBottom - 88; radius: 12
                color: self.ink; opacity: 0
                SequentialAnimation on opacity {
                    id: flash; running: false
                    NumberAnimation { to: 0.5; duration: 55 }
                    NumberAnimation { to: 0; duration: 150; easing.type: Easing.OutQuad }
                }
            }
        }

        // ------------------------------------------------ the machine, sinking away as the tablet comes out
        Item {
            id: machine
            x: 0; y: self.dropD * self.pop
            width: 1536; height: 1024

            Image {
                id: bodyImg
                x: 25; y: 13
                source: self.art("body.png")
                smooth: true; mipmap: true
                MouseArea { anchors.fill: parent }          // (clicks on it stay with it)
            }

            // the keys pressed: each drawn a little lower, in its own shadow
            Repeater {
                model: (self.downRev, Object.keys(self.downKeys))
                Item {
                    id: pk
                    required property string modelData
                    readonly property var b: self.keyBoxes[modelData] ?? [0, 0, 1, 1]
                    x: b[0]; y: b[1]; width: b[2] - b[0]; height: b[3] - b[1]
                    Rectangle { anchors.fill: parent; radius: 6; color: "#141312" }
                    ShaderEffectSource {
                        y: 3; width: parent.width; height: parent.height
                        sourceItem: bodyImg
                        sourceRect: Qt.rect(pk.x - 25, pk.y - 13, pk.width, pk.height)
                    }
                    Rectangle { y: 3; width: parent.width; height: parent.height; radius: 6; color: "black"; opacity: 0.16 }
                }
            }

            // the function keys and the knob, to click
            Repeater {
                model: [["research", "research"], ["sources", "sources"], ["notes", "notes"], ["archive", "archive"], ["return", "research"]]
                MouseArea {
                    required property var modelData
                    readonly property var b: self.keyBoxes[modelData[0]]
                    x: b[0]; y: b[1]; width: b[2] - b[0]; height: b[3] - b[1]
                    cursorShape: Qt.PointingHandCursor
                    onPressed: self.press(modelData[0])
                    onClicked: self.setView(modelData[1])
                }
            }
            MouseArea {
                x: 1222; y: 578; width: 66; height: 66
                cursorShape: Qt.PointingHandCursor
                onClicked: self.togglePop()
            }

            // the carriage, along the line
            Image {
                x: self.carriageX - 61; y: 368
                source: self.art("carriage.png")
                smooth: true; mipmap: true
                Behavior on x { NumberAnimation { duration: self.column === 0 ? 380 : 90; easing.type: Easing.OutCubic } }
            }

            // the feed's lamp: pulsing while it looks something up or saves
            Rectangle {
                x: 1128; y: 543; width: 52; height: 9; radius: 4.5
                color: "#bff59a"
                opacity: Research.busy || Research.exporting ? pulse.v : 0
                Rectangle { anchors.centerIn: parent; width: 80; height: 30; radius: 15; z: -1; color: "#9be05a"; opacity: 0.3 }
                property alias pulseV: pulse.v
                QtObject { id: pulse; property real v: 0.3 }
                SequentialAnimation {
                    running: Research.busy || Research.exporting; loops: Animation.Infinite
                    NumberAnimation { target: pulse; property: "v"; from: 0.2; to: 1; duration: 420 }
                    NumberAnimation { target: pulse; property: "v"; from: 1; to: 0.2; duration: 420 }
                }
            }
        }
    }
}
