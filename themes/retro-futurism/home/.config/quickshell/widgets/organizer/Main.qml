import QtQuick
import QtQuick.Shapes
import Quickshell
import qs.components
import qs.services

// The organizer (art/Calendar.png): the SHINWA digital planner. Its e-ink
// screen is drawn here, live, from the planner (services/Organizer.qml:
// events, tasks, notes and their reminders, kept across restarts).
// Super + C.
//
//   CALENDAR  the month: a dot under a day with events, a square under one
//             with tasks due. Arrows pick a day (its items show below),
//             Page Up / Down or the wheel or ‹ › change the month, Home is
//             today. Below: the day, what is UPCOMING, the REMINDERS.
//   AGENDA    the coming weeks, day by day
//   TASKS     the to-do list: Space ticks one off
//   NOTES     notes: Enter opens one to write in
//
//   anywhere  start typing: a new event (a task in TASKS, a note in NOTES);
//             Enter opens the one chosen; Delete takes it away; Tab and the
//             four keys below the screen change view; the rocker steps;
//             the round key is "new"
//   editing   Tab / ↑ ↓ between its lines, ← → change one, digits set a
//             time, Backspace clears it, Enter saves, Esc leaves
//
// Placed in the mock-up's own pixels (body.png starts at its 36, 12;
// tools/make_organizer.py, which also draws the screen's icons and its
// ginkgo) and scaled once.
Widget {
    id: self
    widgetId: "organizer"

    readonly property real k: 0.66
    preferredWidth: 944 * k
    preferredHeight: 1506 * k

    readonly property color ink: "#343534"
    readonly property color grey: "#9a9995"
    readonly property color paper: "#dad9d4"
    readonly property color light: "#e8e7e2"
    readonly property string font: "Barlow"

    // ---------------------------------------------------------------- state
    property string view: "calendar"          // calendar, agenda, tasks, notes
    readonly property var views: ["calendar", "agenda", "tasks", "notes"]
    property string today: Organizer.today()
    property string sel: today                 // the day chosen
    property int year: new Date().getFullYear()
    property int month: new Date().getMonth()
    property string listMode: "upcoming"       // day, upcoming, reminders
    property int agendaSel: 0
    property int taskSel: 0
    property int noteSel: 0

    // (midnight: today moves on)
    SystemClock { id: clock; precision: SystemClock.Minutes }
    Connections {
        target: clock
        function onDateChanged() { const t = Organizer.today(); if (t !== self.today) self.today = t; }
    }

    function setView(v: string): void {
        if (v === view) return;
        closeNote();
        view = v;
        flash.restart();
        sink.forceActiveFocus();
    }
    function cycleView(d: int): void { setView(views[(views.indexOf(view) + d + 4) % 4]); }
    function pick(k: string): void {
        sel = k;
        const d = Organizer.parse(k);
        if (d.getFullYear() !== year || d.getMonth() !== month) { year = d.getFullYear(); month = d.getMonth(); flash.restart(); }
        listMode = "day";
    }
    function stepMonth(n: int): void {
        let m = month + n, y = year;
        while (m < 0) { m += 12; y--; }
        while (m > 11) { m -= 12; y++; }
        year = y; month = m;
        // the chosen day follows into the month shown
        const d = Organizer.parse(sel);
        const dim = new Date(y, m + 1, 0).getDate();
        sel = Organizer.key(new Date(y, m, Math.min(d.getDate(), dim)));
        flash.restart();
    }
    function goToday(): void { pick(today); listMode = "upcoming"; }

    // the lists, as they are now
    readonly property var dayItems: (Organizer.rev, Organizer.on(sel))
    readonly property var upcomingItems: (Organizer.rev, Organizer.upcoming(today))
    readonly property var reminderItems: (Organizer.rev, Organizer.reminders())
    readonly property var calList: listMode === "day" ? dayItems : listMode === "reminders" ? reminderItems : upcomingItems
    // the agenda, flattened: day headings and items
    readonly property var agendaRows: {
        Organizer.rev;
        const rows = [];
        for (const g of Organizer.agenda(today, 60)) {
            rows.push({ head: true, day: g.day });
            for (const it of g.items) rows.push({ head: false, it: it });
        }
        return rows;
    }
    readonly property var agendaItems: agendaRows.filter(r => !r.head).map(r => r.it)
    readonly property var taskItems: (Organizer.rev, Organizer.tasks())
    readonly property var noteItems: (Organizer.rev, (Organizer.guide ? [Organizer.guide] : []).concat(Organizer.notes))
    readonly property bool reading: noteId === "guide"

    function chosenItem(): var {
        if (view === "agenda") return agendaItems[agendaSel] ?? null;
        if (view === "tasks") return taskItems[taskSel] ?? null;
        if (view === "calendar") return calList[0] ?? null;
        return null;
    }
    function moveSel(d: int): void {
        if (view === "agenda") agendaSel = Math.max(0, Math.min(agendaItems.length - 1, agendaSel + d));
        else if (view === "tasks") taskSel = Math.max(0, Math.min(taskItems.length - 1, taskSel + d));
        else if (view === "notes") noteSel = Math.max(0, Math.min(noteItems.length - 1, noteSel + d));
    }

    // ---------------------------------------------------------------- the editor
    property bool editing: false
    property string eId: ""
    property string eKind: "event"
    property string eDate: ""
    property string eTime: ""
    property int eRemind: -1
    property bool eRemindSet: false
    property int eField: 0                     // 0 title, 1 kind, 2 date, 3 time, 4 reminder, 5 buttons
    property int eButton: 0                    // 0 save, 1 delete, 2 cancel
    property string timeDigits: ""

    function openEditor(it: var, kind: string, start: string): void {
        editing = true;
        eId = it ? it.id : "";
        eKind = it ? it.kind : kind;
        titleInput.text = it ? it.title : start;
        eDate = it ? it.date : (kind === "task" && view === "tasks" ? "" : sel);
        eTime = it ? it.time : "";
        eRemind = it ? it.remind : -1;
        eRemindSet = !!it;
        eField = 0; eButton = 0; timeDigits = "";
        flash.restart();
        titleInput.forceActiveFocus();
        titleInput.cursorPosition = titleInput.text.length;
    }
    function closeEditor(): void { editing = false; sink.forceActiveFocus(); flash.restart(); }
    function saveEditor(): void {
        const title = titleInput.text.trim();
        if (title === "") { closeEditor(); return; }
        const it = { kind: eKind, title: title, date: eKind === "event" && eDate === "" ? sel : eDate, time: eTime, remind: eRemind };
        if (eId) Organizer.update(eId, it);
        else Organizer.add(it);
        if (it.date) pick(it.date);
        closeEditor();
    }
    function deleteEditing(): void { if (eId) Organizer.remove(eId); closeEditor(); }
    function setTime(t: string): void {
        eTime = t;
        if (!eRemindSet && eKind === "event") eRemind = t === "" ? -1 : 10;
    }
    function adjust(d: int, big: bool): void {
        switch (eField) {
        case 1: eKind = eKind === "event" ? "task" : "event"; break;
        case 2: eDate = Organizer.addDays(eDate || sel, d * (big ? 7 : 1)); break;
        case 3: {
            const m = /^(\d{2}):(\d{2})$/.exec(eTime);
            let mins = m ? (+m[1]) * 60 + (+m[2]) : (d > 0 ? 9 * 60 - 15 : 9 * 60 + 15);
            mins = ((mins + d * (big ? 60 : 15)) % 1440 + 1440) % 1440;
            setTime(Organizer.pad(Math.floor(mins / 60)) + ":" + Organizer.pad(mins % 60));
            break;
        }
        case 4: {
            const st = Organizer.remindSteps;
            const i = Math.max(0, st.indexOf(eRemind));
            eRemind = st[Math.max(0, Math.min(st.length - 1, i + d))];
            eRemindSet = true;
            break;
        }
        case 5: eButton = (eButton + d + 3) % 3; if (eButton === 1 && !eId) eButton = (eButton + d + 3) % 3; break;
        }
    }
    function editorKey(e: var): bool {
        switch (e.key) {
        case Qt.Key_Tab: case Qt.Key_Down: eField = (eField + 1) % 6; timeDigits = ""; break;
        case Qt.Key_Backtab: case Qt.Key_Up: eField = (eField + 5) % 6; timeDigits = ""; break;
        case Qt.Key_Left: adjust(-1, e.modifiers & Qt.ShiftModifier); break;
        case Qt.Key_Right: adjust(1, e.modifiers & Qt.ShiftModifier); break;
        case Qt.Key_Return: case Qt.Key_Enter:
            if (eField === 5 && eButton === 1) deleteEditing();
            else if (eField === 5 && eButton === 2) closeEditor();
            else saveEditor();
            break;
        case Qt.Key_Backspace: case Qt.Key_Delete:
            if (eField === 2 && eKind === "task") eDate = "";
            else if (eField === 3) { setTime(""); timeDigits = ""; }
            else if (eField === 4) { eRemind = -1; eRemindSet = true; }
            break;
        default:
            if (eField === 3 && /^[0-9]$/.test(e.text)) {
                timeDigits = (timeDigits + e.text).slice(-4);
                const t = timeDigits.padStart(4, "0");
                const h = Math.min(23, +t.slice(0, 2)), m = Math.min(59, +t.slice(2));
                setTime(Organizer.pad(h) + ":" + Organizer.pad(m));
                break;
            }
            return false;
        }
        return true;
    }

    // ---------------------------------------------------------------- notes
    property string noteId: ""
    function openNote(id: string): void {
        noteId = id;
        const n = Organizer.note(id);
        noteTitle.text = n ? n.title : "";
        noteBody.text = n ? n.body : "";
        noteScroll.contentY = 0;
        flash.restart();
        noteBody.forceActiveFocus();
        if (id === "guide") noteBody.cursorPosition = 0;
    }
    function newNote(start: string): void {
        const id = Organizer.addNote();
        noteSel = 0;
        openNote(id);
        noteTitle.text = start;
        noteTitle.forceActiveFocus();
        noteTitle.cursorPosition = start.length;
    }
    function closeNote(): void {
        if (noteId === "") return;
        if (noteId === "guide") { noteId = ""; flash.restart(); sink.forceActiveFocus(); return; }
        const t = noteTitle.text.trim(), b = noteBody.text;
        if (t === "" && b.trim() === "") Organizer.removeNote(noteId);
        else Organizer.updateNote(noteId, t, b);
        noteId = "";
        flash.restart();
        sink.forceActiveFocus();
    }

    function newHere(start: string): void {
        if (view === "notes") newNote(start);
        else openEditor(null, view === "tasks" ? "task" : "event", start);
    }
    function openChosen(): void {
        if (view === "notes") { const n = noteItems[noteSel]; if (n) openNote(n.id); else newNote(""); return; }
        const it = chosenItem();
        if (it && view !== "calendar") openEditor(it, it.kind, "");
        else newHere("");
    }

    // ---------------------------------------------------------------- keys
    // (the keys go here when no text is being written: the widget's own
    // handlers below get them from it)
    Item { id: sink; focus: true }
    onOpened: sink.forceActiveFocus()
    escapeHandler: () => {
        if (editing) { closeEditor(); return true; }
        if (noteId !== "") { closeNote(); return true; }
        return false;
    }
    Keys.onPressed: e => {
        if (editing) { if (editorKey(e)) e.accepted = true; return; }
        if (noteId !== "") return;
        const shift = e.modifiers & Qt.ShiftModifier;
        switch (e.key) {
        case Qt.Key_Tab: cycleView(1); break;
        case Qt.Key_Backtab: cycleView(-1); break;
        case Qt.Key_F1: setView("calendar"); break;
        case Qt.Key_F2: setView("agenda"); break;
        case Qt.Key_F3: setView("tasks"); break;
        case Qt.Key_F4: setView("notes"); break;
        case Qt.Key_Left:
            if (view === "calendar") pick(Organizer.addDays(sel, -1)); else moveSel(-1);
            break;
        case Qt.Key_Right:
            if (view === "calendar") pick(Organizer.addDays(sel, 1)); else moveSel(1);
            break;
        case Qt.Key_Up:
            if (view === "calendar") pick(Organizer.addDays(sel, -7)); else moveSel(-1);
            break;
        case Qt.Key_Down:
            if (view === "calendar") pick(Organizer.addDays(sel, 7)); else moveSel(1);
            break;
        case Qt.Key_PageUp: if (view === "calendar") stepMonth(-1); else moveSel(-8); break;
        case Qt.Key_PageDown: if (view === "calendar") stepMonth(1); else moveSel(8); break;
        case Qt.Key_Home: if (view === "calendar") goToday(); else moveSel(-9999); break;
        case Qt.Key_End: if (view !== "calendar") moveSel(9999); break;
        case Qt.Key_Return: case Qt.Key_Enter: openChosen(); break;
        case Qt.Key_Space: {
            const it = chosenItem();
            if (it && view !== "calendar") Organizer.toggle(it.id);
            break;
        }
        case Qt.Key_Delete: {
            if (view === "notes") { const n = noteItems[noteSel]; if (n) Organizer.removeNote(n.id); }
            else { const it = chosenItem(); if (it && view !== "calendar") Organizer.remove(it.id); }
            moveSel(0);
            break;
        }
        default:
            if (e.text !== "" && e.text.charCodeAt(0) > 32 && !(e.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
                newHere(e.text);
                break;
            }
            return;
        }
        e.accepted = true;
    }
    // the wheel: the month, in the calendar
    property real wheelRest: 0
    WheelHandler {
        enabled: self.view === "calendar" && !self.editing
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: e => {
            self.wheelRest += e.angleDelta.y;
            const steps = Math.trunc(self.wheelRest / 120);
            if (steps !== 0) { self.wheelRest -= steps * 120; self.stepMonth(-steps); }
        }
    }
    // a key below the screen pressed for a moment (by the keyboard)
    property string tapped: ""
    onViewChanged: { tapped = view; tapTimer.restart(); }
    Timer { id: tapTimer; interval: 160; onTriggered: self.tapped = "" }

    // ================================================================ the planner
    Item {
        id: unit
        width: 944; height: 1506
        scale: self.k
        transformOrigin: Item.TopLeft

        Image {
            anchors.fill: parent
            source: self.art("body.png")
            smooth: true; mipmap: true
        }

        // everything below in the mock-up's own pixels
        Item {
            id: m
            x: -36; y: -12
            width: 1024; height: 1536

            // ---------------------------------------------------- the pieces
            component Ink: Text {
                color: self.ink
                font.family: self.font
                font.pixelSize: 24
                font.weight: Font.Medium
                renderType: Text.QtRendering
            }
            component Rule: Rectangle { height: 2; color: self.ink; opacity: 0.85 }
            component Icon: Image {
                property string name
                property bool lit: false
                source: self.art("icon-" + name + (lit ? "-light" : "-ink") + ".svg")
                sourceSize: Qt.size(96, 96)
                smooth: true; mipmap: true
            }
            // a chip with two corners cut (top left, bottom right) and a slash
            component Chip: Shape {
                id: chip
                property real cut: 14
                property bool filled: true
                property color tone: self.ink
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: chip.filled ? chip.tone : "transparent"
                    strokeColor: chip.tone
                    strokeWidth: chip.filled ? 0 : 2.5
                    startX: chip.cut; startY: 0
                    PathLine { x: chip.width; y: 0 }
                    PathLine { x: chip.width; y: chip.height - chip.cut }
                    PathLine { x: chip.width - chip.cut; y: chip.height }
                    PathLine { x: 0; y: chip.height }
                    PathLine { x: 0; y: chip.cut }
                    PathLine { x: chip.cut; y: 0 }
                }
                ShapePath {
                    strokeColor: chip.filled ? self.light : chip.tone
                    strokeWidth: 1.6
                    fillColor: "transparent"
                    startX: 3; startY: chip.cut + 6
                    PathLine { x: chip.cut + 6; y: 3 }
                }
            }
            component Box: Rectangle {
                property bool ticked: false
                width: 20; height: 20; radius: 2
                color: "transparent"
                border.width: 2; border.color: self.ink
                Shape {
                    anchors.fill: parent
                    visible: parent.ticked
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: self.ink; strokeWidth: 2.6; fillColor: "transparent"
                        capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
                        startX: 4; startY: 10.5
                        PathLine { x: 8.5; y: 15 }
                        PathLine { x: 16.5; y: 5 }
                    }
                }
            }

            // ---------------------------------------------------- the screen
            Item {
                id: screen
                x: 0; y: 0; width: 1024; height: 1536

                // its top line: what it is, the time, the battery
                Icon { name: "calendar"; x: 145; y: 160; width: 44; height: 44 }
                Ink { x: 209; y: 181 - height / 2; text: "Organizer"; font.pixelSize: 29; font.weight: Font.Normal }
                Rule { x: 362; y: 187; width: 306; height: 1.6 }
                Rule { x: 664; y: 183; width: 11; height: 1.6; rotation: -40 }
                Ink {
                    x: 798 - width; y: 181 - height / 2
                    font.pixelSize: 38; font.weight: Font.Normal; font.letterSpacing: 1
                    text: Qt.formatTime(clock.date, "hh:mm")
                }
                Item {
                    x: 835; y: 167; width: 64; height: 30
                    Rectangle { width: 57; height: 30; radius: 4; color: "transparent"; border.width: 3; border.color: self.ink }
                    Rectangle { x: 57; y: 9; width: 6; height: 12; radius: 1.5; color: self.ink }
                    Row {
                        x: 7; y: 7; spacing: 3
                        Repeater {
                            model: 4
                            Rectangle {
                                required property int index
                                width: 8.6; height: 16; color: self.ink
                                opacity: !Power.present || Power.percent > index * 25 + 5 ? 1 : 0.12
                            }
                        }
                    }
                }
                Rule { x: 137; y: 224; width: 770 }

                // the ginkgo, in its corner, on every page
                Image {
                    x: 664; y: 232; width: 250; height: 193
                    source: self.art("ginkgo.svg")
                    sourceSize: Qt.size(440, 340)
                    smooth: true
                    opacity: 0.92
                }
                Shape {
                    x: 868; y: 378; width: 38; height: 34
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: self.ink; strokeWidth: 1.6; fillColor: "transparent"
                        startX: 0; startY: 32
                        PathLine { x: 36; y: 32 }
                        PathLine { x: 36; y: 0 }
                    }
                    ShapePath {
                        strokeColor: self.ink; strokeWidth: 1.6; fillColor: "transparent"
                        startX: 16; startY: 27; PathLine { x: 30; y: 13 }
                    }
                    ShapePath {
                        strokeColor: self.ink; strokeWidth: 1.6; fillColor: "transparent"
                        startX: 22; startY: 27; PathLine { x: 31; y: 18 }
                    }
                }

                // its big heading, and the line under it
                Ink {
                    x: 146; y: 316 - height / 2
                    width: 560; elide: Text.ElideRight
                    font.pixelSize: 76; font.weight: Font.Normal; font.letterSpacing: -0.5
                    text: self.editing ? (self.eId ? "EDIT " : "NEW ") + self.eKind.toUpperCase()
                        : self.noteId !== "" ? (self.reading ? "GUIDE" : "NOTE")
                        : self.view === "calendar" ? Organizer.monthNames[self.month] + " " + self.year
                        : self.view.toUpperCase()
                }
                Ink {
                    x: 152; y: 380 - height / 2
                    font.pixelSize: 26; font.letterSpacing: 7; font.weight: Font.Medium
                    text: {
                        if (self.editing) return self.eDate ? Organizer.longLabel(self.eDate) : "NO DATE";
                        if (self.noteId !== "") return self.reading ? "↑ ↓  READ  ·  ESC  CLOSE" : "WRITE BELOW  ·  ESC TO CLOSE";
                        switch (self.view) {
                        case "calendar": return Organizer.longLabel(self.sel);
                        case "agenda": return "FROM " + Organizer.longLabel(self.today);
                        case "tasks": {
                            const open = self.taskItems.filter(t => !t.done).length;
                            return open + " OPEN  ·  " + (self.taskItems.length - open) + " DONE";
                        }
                        default: { const n = Organizer.notes.length; return n + (n === 1 ? " NOTE" : " NOTES") + (Organizer.guide ? "  ·  THE GUIDE" : ""); }
                        }
                    }
                }

                // ================================================ CALENDAR
                Item {
                    id: cal
                    anchors.fill: parent
                    visible: self.view === "calendar" && !self.editing

                    // the month's row: ‹  ≡  NOVEMBER 2026  ≡  ›
                    component Chevron: Shape {
                        property bool toRight: false
                        width: 24; height: 40
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeColor: self.ink; strokeWidth: 2.4; fillColor: "transparent"
                            capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
                            startX: toRight ? 4 : 20; startY: 3
                            PathLine { x: toRight ? 20 : 4; y: 20 }
                            PathLine { x: toRight ? 4 : 20; y: 37 }
                        }
                    }
                    Chevron { x: 140; y: 442 }
                    Chevron { x: 868; y: 442; toRight: true }
                    MouseArea { x: 120; y: 425; width: 80; height: 75; cursorShape: Qt.PointingHandCursor; onClicked: self.stepMonth(-1) }
                    MouseArea { x: 840; y: 425; width: 80; height: 75; cursorShape: Qt.PointingHandCursor; onClicked: self.stepMonth(1) }
                    Repeater {
                        model: [[235, 456, 63], [242, 463, 56], [249, 470, 49], [735, 456, 63], [735, 463, 56], [735, 470, 49]]
                        Rectangle { required property var modelData; x: modelData[0]; y: modelData[1]; width: modelData[2]; height: 1.6; color: self.ink }
                    }
                    Ink {
                        x: 520 - width / 2; y: 463 - height / 2
                        font.pixelSize: 25; font.letterSpacing: 8; font.weight: Font.Medium
                        text: Organizer.monthNames[self.month] + " " + self.year
                    }
                    MouseArea {
                        x: 320; y: 440; width: 400; height: 50
                        cursorShape: Qt.PointingHandCursor
                        onClicked: self.goToday()
                    }

                    // the days of the week
                    readonly property var cols: [190, 300, 410, 520, 632, 742, 853]
                    readonly property var rows: [587, 647, 709, 771, 835, 897]
                    Repeater {
                        model: ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
                        Ink {
                            required property string modelData
                            required property int index
                            x: cal.cols[index] - width / 2; y: 525 - height / 2
                            font.pixelSize: 22; font.letterSpacing: 1
                            text: modelData
                        }
                    }
                    Rule { x: 137; y: 553; width: 770 }

                    // the days: six weeks from the Sunday on or before the 1st
                    readonly property date first: new Date(self.year, self.month, 1)
                    Repeater {
                        model: 42
                        Item {
                            id: cell
                            required property int index
                            readonly property date day: new Date(self.year, self.month, 1 - cal.first.getDay() + index)
                            readonly property string key: Organizer.key(day)
                            readonly property bool inMonth: day.getMonth() === self.month
                            readonly property bool isToday: key === self.today
                            readonly property bool chosen: key === self.sel
                            readonly property int events: (Organizer.rev, Organizer.eventsOn(key))
                            readonly property int tasks: (Organizer.rev, Organizer.tasksOn(key))
                            x: cal.cols[index % 7] - 50; y: cal.rows[Math.floor(index / 7)] - 30
                            width: 100; height: 60

                            Chip {
                                visible: cell.isToday || cell.chosen
                                filled: cell.isToday
                                x: 4; y: 2; width: 92; height: 56; cut: 13
                            }
                            Ink {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 30 - height / 2 - (cell.events || cell.tasks ? 3 : 0)
                                font.pixelSize: 32; font.weight: Font.Normal
                                color: cell.isToday ? self.light : cell.inMonth ? self.ink : self.grey
                                text: cell.day.getDate()
                            }
                            // what it has: a dot for events, a square for tasks
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 47
                                spacing: 5
                                Rectangle {
                                    visible: cell.events > 0
                                    width: 7; height: 7; radius: 3.5
                                    color: cell.isToday ? self.light : self.ink
                                    opacity: cell.inMonth ? 1 : 0.5
                                }
                                Rectangle {
                                    visible: cell.tasks > 0
                                    width: 9; height: 9; y: -1
                                    color: "transparent"
                                    border.width: 1.6; border.color: cell.isToday ? self.light : self.ink
                                    opacity: cell.inMonth ? 1 : 0.5
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: self.pick(cell.key)
                                onDoubleClicked: { self.pick(cell.key); self.openEditor(null, "event", ""); }
                            }
                        }
                    }

                    // ---- below: the day, upcoming, reminders | their list
                    Shape {
                        x: 128; y: 960; width: 780; height: 18
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeColor: self.ink; strokeWidth: 2; fillColor: "transparent"
                            startX: 2; startY: 16
                            PathLine { x: 22; y: 2 }
                            PathLine { x: 779; y: 2 }
                        }
                    }
                    Item {
                        x: 137; y: 975; width: 260; height: 80
                        Ink {
                            x: 18; y: 20 - height / 2
                            font.pixelSize: 21; font.letterSpacing: 6
                            text: self.sel === self.today ? "TODAY" : Organizer.dayLong[Organizer.parse(self.sel).getDay()]
                        }
                        Ink {
                            x: 23; y: 51 - height / 2
                            font.pixelSize: 23; font.weight: Font.Normal
                            text: Organizer.dayLabel(self.sel)
                        }
                        Rectangle { x: 2; y: 12; width: 5; height: 48; color: self.ink; visible: self.listMode === "day" }
                        Rule { x: 228; y: 26; width: 30; height: 1.5; rotation: -48 }
                        Rule { x: 236; y: 26; width: 30; height: 1.5; rotation: -48 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: self.listMode = "day" }
                    }
                    Rule { x: 137; y: 1055; width: 258; height: 1.5 }
                    Repeater {
                        model: [["upcoming", "UPCOMING", "play", 1080], ["reminders", "REMINDERS", "bell", 1131]]
                        Item {
                            required property var modelData
                            x: 137; y: modelData[3] - 24; width: 258; height: 48
                            Rectangle { x: 2; y: 6; width: 5; height: 36; color: self.ink; visible: self.listMode === parent.modelData[0] }
                            Icon { name: parent.modelData[2]; x: modelData[2] === "play" ? 20 : 17; y: modelData[2] === "play" ? 15 : 12; width: modelData[2] === "play" ? 19 : 25; height: width }
                            Ink {
                                x: 64; y: 24 - height / 2
                                font.pixelSize: 19; font.letterSpacing: 4.5
                                font.weight: self.listMode === parent.modelData[0] ? Font.Bold : Font.Medium
                                text: parent.modelData[1]
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: self.listMode = parent.modelData[0] }
                        }
                    }
                    Rule { x: 137; y: 1105; width: 258; height: 1.5 }
                    Rectangle { x: 427; y: 988; width: 1.6; height: 156; color: self.ink }

                    // the list
                    Repeater {
                        model: self.calList.slice(0, 3)
                        Item {
                            id: row
                            required property var modelData
                            required property int index
                            readonly property var it: modelData
                            x: 465; y: 1010 + index * 50 - 24; width: 445; height: 48
                            Box {
                                x: 7; y: 14
                                ticked: !!row.it.done
                                MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: Organizer.toggle(row.it.id) }
                            }
                            Ink {
                                x: 57; y: 24 - height / 2; width: 385
                                elide: Text.ElideRight
                                font.pixelSize: 24; font.weight: Font.Normal
                                font.strikeout: !!row.it.done
                                color: row.it.done ? self.grey : self.ink
                                text: {
                                    const it = row.it;
                                    if (self.listMode === "day") return (it.time ? it.time + "  " : "") + it.title;
                                    const when = it.date ? Organizer.short(it.date) + (self.listMode === "reminders" && it.time ? " " + it.time : "") : "";
                                    return it.title + (when ? " — " + when : "");
                                }
                            }
                            MouseArea {
                                x: 50; width: parent.width - 50; height: parent.height
                                cursorShape: Qt.PointingHandCursor
                                onClicked: self.openEditor(row.it, row.it.kind, "")
                            }
                        }
                    }
                    Ink {
                        visible: self.calList.length === 0
                        x: 522; y: 1035
                        font.pixelSize: 21; font.weight: Font.Normal
                        color: self.grey
                        text: self.listMode === "day" ? "Nothing on this day." : self.listMode === "reminders" ? "No reminders set." : "Nothing coming up."
                    }
                    Ink {
                        visible: self.calList.length === 0
                        x: 522; y: 1075
                        font.pixelSize: 16; font.letterSpacing: 3.5
                        color: self.grey
                        text: "TYPE TO ADD  ·  ENTER  NEW"
                    }
                    Ink {
                        visible: self.calList.length > 3
                        x: 905 - width; y: 1140
                        font.pixelSize: 15; font.letterSpacing: 3
                        color: self.grey
                        text: "+" + (self.calList.length - 3) + " MORE"
                    }
                }

                // ================================================ the lists (agenda, tasks, notes)
                component ListPage: Item {
                    id: page
                    property alias model: list.model
                    property alias delegate: list.delegate
                    property int current: 0
                    property string empty: ""
                    property string hints: ""
                    readonly property alias list: list
                    anchors.fill: parent
                    Rule { x: 137; y: 432; width: 770 }
                    ListView {
                        id: list
                        x: 137; y: 444; width: 770; height: 662
                        clip: true
                        currentIndex: page.current
                        highlightMoveDuration: 0
                        boundsBehavior: Flickable.StopAtBounds
                        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                    }
                    Ink {
                        visible: list.count === 0
                        x: 152; y: 520
                        font.pixelSize: 26; font.weight: Font.Normal
                        color: self.grey
                        text: page.empty
                    }
                    Rule { x: 137; y: 1112; width: 770; height: 1.5; opacity: 0.6 }
                    Ink {
                        x: 152; y: 1142 - height / 2
                        font.pixelSize: 15; font.letterSpacing: 3
                        color: self.grey
                        text: page.hints
                    }
                }
                component ItemRow: Item {
                    id: ir
                    property var it
                    property bool current: false
                    property bool showDate: true
                    property bool showWhen: true
                    width: 770; height: 58
                    Rectangle {
                        anchors.fill: parent; anchors.leftMargin: 0
                        color: "transparent"
                        border.width: ir.current ? 2.5 : 0; border.color: self.ink
                        radius: 3
                    }
                    Rectangle { x: 0; y: 6; width: 5; height: 46; color: self.ink; visible: ir.current }
                    Box {
                        visible: ir.it.kind === "task"
                        x: 22; y: 19; ticked: !!ir.it.done
                        MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: Organizer.toggle(ir.it.id) }
                    }
                    Rectangle { visible: ir.it.kind === "event"; x: 28; y: 25; width: 9; height: 9; radius: 4.5; color: self.ink }
                    Ink {
                        visible: ir.showWhen
                        x: 62; y: 29 - height / 2; width: 100
                        font.pixelSize: 21; font.letterSpacing: 1
                        color: self.grey
                        text: ir.it.time || (ir.it.kind === "task" ? "TASK" : "ALL DAY")
                    }
                    Ink {
                        x: ir.showWhen ? 170 : 66; y: 29 - height / 2; width: (ir.showDate ? 430 : 540) + (ir.showWhen ? 0 : 104)
                        elide: Text.ElideRight
                        font.pixelSize: 26; font.weight: Font.Normal
                        font.strikeout: !!ir.it.done
                        color: ir.it.done ? self.grey : self.ink
                        text: ir.it.title
                    }
                    Ink {
                        visible: ir.showDate && ir.it.date !== ""
                        x: 735 - width; y: 29 - height / 2
                        font.pixelSize: 20; font.letterSpacing: 1.5
                        color: self.grey
                        text: Organizer.short(ir.it.date).toUpperCase()
                    }
                    Icon {
                        visible: ir.it.remind >= 0 && !ir.it.fired && !ir.it.done
                        name: "bell"; x: 740; y: 17; width: 24; height: 24
                        opacity: 0.8
                    }
                }

                // ---- AGENDA
                ListPage {
                    visible: self.view === "agenda" && !self.editing
                    model: self.agendaRows
                    current: -1
                    empty: "Nothing planned. Type to add an event."
                    hints: "ENTER  OPEN  ·  SPACE  DONE  ·  DEL  DELETE  ·  TYPE  NEW"
                    delegate: Item {
                        id: ar
                        required property var modelData
                        required property int index
                        readonly property int itemIndex: self.agendaRows.slice(0, index).filter(r => !r.head).length
                        width: 770; height: modelData.head ? 62 : 58
                        Item {
                            visible: ar.modelData.head
                            anchors.fill: parent
                            Ink {
                                x: 4; y: 38 - height / 2
                                font.pixelSize: 20; font.letterSpacing: 5; font.weight: Font.Bold
                                text: !ar.modelData.day ? "NO DATE"
                                    : Organizer.longLabel(ar.modelData.day) + (ar.modelData.day === self.today ? "  —  TODAY"
                                        : ar.modelData.day === Organizer.addDays(self.today, 1) ? "  —  TOMORROW" : "")
                            }
                            Rectangle { x: 0; y: 56; width: 770; height: 1.4; color: self.ink; opacity: 0.5 }
                        }
                        ItemRow {
                            visible: !ar.modelData.head
                            it: ar.modelData.it ?? ({ kind: "event", title: "", date: "", time: "", remind: -1 })
                            showDate: false
                            current: !ar.modelData.head && ar.itemIndex === self.agendaSel
                            MouseArea {
                                anchors.fill: parent; anchors.leftMargin: 56
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { self.agendaSel = ar.itemIndex; self.openEditor(ar.modelData.it, ar.modelData.it.kind, ""); }
                            }
                        }
                    }
                }

                // ---- TASKS
                ListPage {
                    visible: self.view === "tasks" && !self.editing
                    model: self.taskItems
                    current: self.taskSel
                    empty: "No tasks. Type one to add it."
                    hints: "SPACE  TICK  ·  ENTER  OPEN  ·  DEL  DELETE  ·  TYPE  NEW"
                    delegate: ItemRow {
                        required property var modelData
                        required property int index
                        it: modelData
                        showWhen: false
                        current: index === self.taskSel
                        MouseArea {
                            anchors.fill: parent; anchors.leftMargin: 56
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { self.taskSel = parent.index; self.openEditor(parent.modelData, "task", ""); }
                        }
                    }
                }

                // ---- NOTES
                ListPage {
                    visible: self.view === "notes" && self.noteId === ""
                    model: self.noteItems
                    current: self.noteSel
                    empty: "No notes. Type to start one."
                    hints: "ENTER  OPEN  ·  DEL  DELETE  ·  TYPE  NEW"
                    delegate: Item {
                        id: nr
                        required property var modelData
                        required property int index
                        width: 770; height: 86
                        Rectangle {
                            anchors.fill: parent; anchors.topMargin: 3; anchors.bottomMargin: 3
                            color: "transparent"; radius: 3
                            border.width: nr.index === self.noteSel ? 2.5 : 0; border.color: self.ink
                        }
                        Rectangle { x: 0; y: 10; width: 5; height: 66; color: self.ink; visible: nr.index === self.noteSel }
                        Icon { name: "notes"; x: 20; y: 24; width: 34; height: 34 }
                        Ink {
                            x: 74; y: 14; width: 520
                            elide: Text.ElideRight
                            font.pixelSize: 26; font.weight: Font.Medium
                            text: nr.modelData.title || "Untitled"
                        }
                        Ink {
                            x: 74; y: 48; width: 640
                            elide: Text.ElideRight
                            font.pixelSize: 19; font.weight: Font.Normal
                            color: self.grey
                            text: (nr.modelData.body || "").replace(/\s+/g, " ").trim() || "—"
                        }
                        Ink {
                            x: 750 - width; y: 18
                            font.pixelSize: 17; font.letterSpacing: 2
                            color: self.grey
                            text: nr.modelData.pinned ? "GUIDE" : Organizer.short(Organizer.key(new Date(nr.modelData.updated))).toUpperCase()
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { self.noteSel = nr.index; self.openNote(nr.modelData.id); }
                        }
                    }
                }

                // ---- a note, open
                Item {
                    visible: self.view === "notes" && self.noteId !== ""
                    anchors.fill: parent
                    Rule { x: 137; y: 432; width: 770 }
                    TextInput {
                        id: noteTitle
                        readOnly: self.reading
                        x: 152; y: 452; width: 740
                        color: self.ink
                        font.family: self.font; font.pixelSize: 36; font.weight: Font.Medium
                        selectionColor: self.ink; selectedTextColor: self.light
                        clip: true
                        Keys.onPressed: e => {
                            if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Down || e.key === Qt.Key_Tab) {
                                noteBody.forceActiveFocus(); e.accepted = true;
                            }
                        }
                        Ink {
                            visible: noteTitle.text === "" && !noteTitle.activeFocus
                            font: noteTitle.font; color: self.grey; text: "Title"
                        }
                    }
                    Rule { x: 152; y: 506; width: 740; height: 1.5; opacity: 0.5 }
                    Flickable {
                        id: noteScroll
                        x: 152; y: 522; width: 740; height: 580
                        contentHeight: noteBody.contentHeight + 20
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        TextEdit {
                            id: noteBody
                            readOnly: self.reading
                            width: noteScroll.width
                            color: self.ink
                            font.family: self.font; font.pixelSize: self.reading ? 23 : 26; font.weight: Font.Normal
                            wrapMode: TextEdit.Wrap
                            selectionColor: self.ink; selectedTextColor: self.light
                            onCursorRectangleChanged: {
                                const r = cursorRectangle;
                                if (r.y < noteScroll.contentY) noteScroll.contentY = r.y;
                                else if (r.y + r.height > noteScroll.contentY + noteScroll.height) noteScroll.contentY = r.y + r.height - noteScroll.height;
                            }
                            Keys.onPressed: e => {
                                if (self.reading) {
                                    const page = noteScroll.height * 0.9, most = Math.max(0, noteScroll.contentHeight - noteScroll.height);
                                    const d = { [Qt.Key_Up]: -70, [Qt.Key_Down]: 70, [Qt.Key_PageUp]: -page, [Qt.Key_PageDown]: page, [Qt.Key_Space]: page }[e.key];
                                    if (d !== undefined) { noteScroll.contentY = Math.max(0, Math.min(most, noteScroll.contentY + d)); e.accepted = true; return; }
                                    if (e.key === Qt.Key_Home) { noteScroll.contentY = 0; e.accepted = true; return; }
                                }
                                if (e.key === Qt.Key_Up && cursorRectangle.y < 4) { noteTitle.forceActiveFocus(); e.accepted = true; }
                                else if (e.key === Qt.Key_Tab) { insert(cursorPosition, "    "); e.accepted = true; }
                            }
                            Ink {
                                visible: noteBody.text === "" && !noteBody.activeFocus
                                font: noteBody.font; color: self.grey; text: "Write here…"
                            }
                        }
                    }
                    Rule { x: 137; y: 1112; width: 770; height: 1.5; opacity: 0.6 }
                    Ink {
                        x: 152; y: 1142 - height / 2
                        font.pixelSize: 15; font.letterSpacing: 3
                        color: self.grey
                        text: self.reading ? "COMES WITH THE THEME  ·  RENEWED BY EVERY UPDATE" : "SAVED AS YOU WRITE  ·  ESC  CLOSE"
                    }
                }

                // ================================================ the editor
                Item {
                    id: form
                    visible: self.editing
                    anchors.fill: parent
                    Rule { x: 137; y: 432; width: 770 }

                    component Field: Item {
                        id: fld
                        property int n
                        property string label
                        property string value
                        property bool arrows: true
                        readonly property bool on: self.eField === n
                        x: 137; width: 770; height: 74
                        Rectangle {
                            anchors.fill: parent; anchors.topMargin: 4; anchors.bottomMargin: 4
                            color: "transparent"; radius: 3
                            border.width: fld.on ? 2.5 : 0; border.color: self.ink
                        }
                        Rectangle { x: 0; y: 12; width: 5; height: 50; color: self.ink; visible: fld.on }
                        Ink {
                            x: 24; y: 37 - height / 2
                            font.pixelSize: 18; font.letterSpacing: 4
                            color: self.grey
                            text: fld.label
                        }
                        Ink {
                            x: 230; y: 37 - height / 2; width: 470
                            horizontalAlignment: fld.arrows ? Text.AlignHCenter : Text.AlignLeft
                            font.pixelSize: 26; font.letterSpacing: 2; font.weight: Font.Medium
                            text: fld.value
                        }
                        Ink { visible: fld.arrows && fld.on; x: 236; y: 37 - height / 2; text: "‹"; font.pixelSize: 34 }
                        Ink { visible: fld.arrows && fld.on; x: 690; y: 37 - height / 2; text: "›"; font.pixelSize: 34 }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: m => {
                                self.eField = fld.n;
                                if (fld.arrows && m.x > 230) self.adjust(m.x < 465 ? -1 : 1, false);
                                sink.forceActiveFocus();
                            }
                        }
                    }

                    // the title
                    Item {
                        x: 137; y: 448; width: 770; height: 92
                        Rectangle {
                            anchors.fill: parent; anchors.topMargin: 4; anchors.bottomMargin: 4
                            color: "transparent"; radius: 3
                            border.width: self.eField === 0 ? 2.5 : 0; border.color: self.ink
                        }
                        Rectangle { x: 0; y: 12; width: 5; height: 68; color: self.ink; visible: self.eField === 0 }
                        TextInput {
                            id: titleInput
                            x: 24; y: 46 - height / 2; width: 720
                            color: self.ink
                            font.family: self.font; font.pixelSize: 38; font.weight: Font.Medium
                            selectionColor: self.ink; selectedTextColor: self.light
                            clip: true
                            onActiveFocusChanged: if (activeFocus) self.eField = 0
                            Keys.onPressed: e => {
                                if ([Qt.Key_Tab, Qt.Key_Backtab, Qt.Key_Down, Qt.Key_Up, Qt.Key_Return, Qt.Key_Enter].includes(e.key)) {
                                    self.editorKey(e);
                                    if (self.eField !== 0) sink.forceActiveFocus();
                                    e.accepted = true;
                                }
                            }
                            Ink {
                                visible: titleInput.text === ""
                                font: titleInput.font; color: self.grey
                                text: self.eKind === "task" ? "What needs doing?" : "What is happening?"
                            }
                        }
                        MouseArea { anchors.fill: parent; z: -1; onClicked: titleInput.forceActiveFocus() }
                    }
                    onVisibleChanged: if (!visible) self.eField = 0
                    Connections {
                        target: self
                        function onEFieldChanged() { if (self.eField === 0 && self.editing) titleInput.forceActiveFocus(); }
                    }

                    Field { n: 1; y: 552; label: "KIND"; value: self.eKind === "task" ? "TASK" : "EVENT" }
                    Field {
                        n: 2; y: 626; label: "DATE"
                        value: self.eDate ? Organizer.longLabel(self.eDate) : (self.eKind === "task" ? "NO DATE" : Organizer.longLabel(self.sel))
                    }
                    Field { n: 3; y: 700; label: "TIME"; value: self.eTime || (self.eKind === "task" ? "ANY TIME" : "ALL DAY") }
                    Field { n: 4; y: 774; label: "REMINDER"; value: Organizer.remindText(self.eRemind) }

                    // its buttons
                    Row {
                        x: 152; y: 880
                        spacing: 22
                        Repeater {
                            model: self.eId ? ["SAVE", "DELETE", "CANCEL"] : ["SAVE", "CANCEL"]
                            Item {
                                id: btn
                                required property string modelData
                                required property int index
                                readonly property int which: modelData === "SAVE" ? 0 : modelData === "DELETE" ? 1 : 2
                                readonly property bool on: self.eField === 5 && self.eButton === which
                                width: 200; height: 64
                                Chip { anchors.fill: parent; cut: 12; filled: btn.on || (btn.which === 0 && self.eField !== 5) }
                                Ink {
                                    anchors.centerIn: parent
                                    font.pixelSize: 21; font.letterSpacing: 4
                                    color: btn.on || (btn.which === 0 && self.eField !== 5) ? self.light : self.ink
                                    text: btn.modelData
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: btn.which === 0 ? self.saveEditor() : btn.which === 1 ? self.deleteEditing() : self.closeEditor()
                                }
                            }
                        }
                    }
                    Ink {
                        x: 152; y: 990; width: 740
                        wrapMode: Text.Wrap
                        font.pixelSize: 15; font.letterSpacing: 3; lineHeight: 1.5
                        color: self.grey
                        text: "TAB / ↑ ↓  MOVE  ·  ← →  CHANGE  ·  DIGITS  SET THE TIME  ·  BACKSPACE  CLEAR  ·  ENTER  SAVE  ·  ESC  LEAVE"
                    }
                }

                // ================================================ its tabs
                Rule { x: 137; y: 1172; width: 770; visible: true }
                Repeater {
                    model: [["calendar", "CALENDAR", 127, 228, 154, 200], ["agenda", "AGENDA", 363, 187, 386, 430],
                            ["tasks", "TASKS", 550, 188, 582, 636], ["notes", "NOTES", 738, 170, 776, 832]]
                    Item {
                        id: tab
                        required property var modelData
                        required property int index
                        readonly property bool on: self.view === modelData[0]
                        x: modelData[2]; y: 1200; width: modelData[3]; height: 66
                        Chip { visible: tab.on; anchors.fill: parent; cut: 14 }
                        Icon {
                            name: tab.modelData[0]; lit: tab.on
                            x: tab.modelData[4] - tab.modelData[2]; y: 17; width: 32; height: 32
                        }
                        Ink {
                            x: tab.modelData[5] - tab.modelData[2]; y: 33 - height / 2
                            font.pixelSize: 23; font.letterSpacing: 1.2; font.weight: Font.Medium
                            color: tab.on ? self.light : self.ink
                            text: tab.modelData[1]
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: self.setView(tab.modelData[0]) }
                    }
                }
                Repeater {
                    model: [363, 550, 738]
                    Rectangle { required property real modelData; x: modelData; y: 1211; width: 1.6; height: 46; color: self.ink }
                }

                // ---- an e-ink page turns with a quick dark flash
                Rectangle {
                    x: 102; y: 136; width: 829; height: 1172; radius: 14
                    color: self.ink
                    opacity: 0
                    SequentialAnimation on opacity {
                        id: flash
                        running: false
                        NumberAnimation { to: 0.55; duration: 55 }
                        NumberAnimation { to: 0.0; duration: 150; easing.type: Easing.OutQuad }
                    }
                }
            }

            // ---------------------------------------------------- its keys
            component Key: Image {
                id: key
                property string name
                property var at
                signal hit()
                readonly property bool down: area.pressed || self.tapped === name
                source: self.art("key-" + name + ".png")
                x: at[0]; y: at[1] + (down ? 3 : 0)
                smooth: true; mipmap: true
                Rectangle { anchors.fill: parent; radius: 10; color: "black"; opacity: key.down ? 0.18 : 0 }
                MouseArea { id: area; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: key.hit() }
            }
            Key { name: "calendar"; at: [259, 1389]; onHit: self.setView("calendar") }
            Key { name: "agenda"; at: [348, 1389]; onHit: self.setView("agenda") }
            Key { name: "tasks"; at: [434, 1389]; onHit: self.setView("tasks") }
            Key { name: "notes"; at: [520, 1389]; onHit: self.setView("notes") }
            Key {
                name: "prev"; at: [655, 1388]
                onHit: { if (self.editing) self.adjust(-1, false); else if (self.view === "calendar") self.stepMonth(-1); else self.moveSel(-1); }
            }
            Key {
                name: "next"; at: [749, 1388]
                onHit: { if (self.editing) self.adjust(1, false); else if (self.view === "calendar") self.stepMonth(1); else self.moveSel(1); }
            }
            Key { name: "round"; at: [866, 1378]; onHit: { if (!self.editing) self.newHere(""); } }

            // its side wheel: the month, or the list
            MouseArea {
                x: 40; y: 268; width: 28; height: 170
                cursorShape: Qt.SizeVerCursor
                property real y0: 0
                onPressed: e => y0 = e.y
                onPositionChanged: e => {
                    if (!pressed) return;
                    const steps = Math.trunc((e.y - y0) / 24);
                    if (steps === 0) return;
                    y0 += steps * 24;
                    if (self.view === "calendar") self.stepMonth(steps); else self.moveSel(steps);
                }
            }
        }
    }
}
