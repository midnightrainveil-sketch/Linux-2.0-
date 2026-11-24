pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The organizer's planner (widgets/organizer): events, tasks and notes, kept
// in ~/.local/state/ultra/retro-futurism/organizer.json. It runs from the
// shell's start (shell.qml), so its reminders come on time whether the
// organizer is up or not: as notifications (the pager), a tap on one
// bringing the organizer up.
//
//   items   [{ id, kind: "event" | "task", title, date: "2026-11-18" | "",
//              time: "14:30" | "", done, remind: minutes before (-1 none),
//              fired }]
//   notes   [{ id, title, body, updated }]
//   rev     goes up on every change (bindings that read the lists use it)
Singleton {
    id: root

    property var items: []
    property var notes: []
    property int rev: 0
    property bool loaded: false

    // ---------------------------------------------------------------- dates
    function pad(n: int): string { return (n < 10 ? "0" : "") + n; }
    function key(d: date): string { return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate()); }
    function parse(k: string): date {
        const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(k || "");
        return m ? new Date(+m[1], +m[2] - 1, +m[3]) : new Date(NaN);
    }
    function today(): string { return key(new Date()); }
    function addDays(k: string, n: int): string { const d = parse(k); d.setDate(d.getDate() + n); return key(d); }
    readonly property var monthNames: ["JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"]
    readonly property var monthShort: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    readonly property var dayShort: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    readonly property var dayLong: ["SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"]
    // "18 Nov"
    function short(k: string): string { const d = parse(k); return isNaN(d) ? "" : d.getDate() + " " + monthShort[d.getMonth()]; }
    // "Tue, 17 Nov"
    function dayLabel(k: string): string { const d = parse(k); return isNaN(d) ? "" : dayShort[d.getDay()] + ", " + d.getDate() + " " + monthShort[d.getMonth()]; }
    // "TUE, 17 NOV 2026"
    function longLabel(k: string): string {
        const d = parse(k);
        return isNaN(d) ? "" : dayShort[d.getDay()].toUpperCase() + ", " + d.getDate() + " " + monthShort[d.getMonth()].toUpperCase() + " " + d.getFullYear();
    }
    // when: "2026-11-18 14:30" sorts as it should ("" dates last)
    function when(it: var): string { return (it.date || "9999-99-99") + " " + (it.time || "99:99"); }

    // ---------------------------------------------------------------- reading
    function on(k: string): var {
        return items.filter(it => it.date === k).sort((a, b) => when(a).localeCompare(when(b)));
    }
    function eventsOn(k: string): int { return items.filter(it => it.date === k && it.kind === "event").length; }
    function tasksOn(k: string): int { return items.filter(it => it.date === k && it.kind === "task" && !it.done).length; }
    // what is still to come from day k: events from it on, tasks not done
    function upcoming(k: string): var {
        return items.filter(it => it.kind === "event" ? (it.date !== "" && it.date >= k) : !it.done)
            .sort((a, b) => when(a).localeCompare(when(b)));
    }
    // the reminders still to come, soonest first
    function reminders(): var {
        const now = Date.now();
        return items.filter(it => it.remind >= 0 && !it.done && !it.fired && remindAt(it) > now - 60000)
            .sort((a, b) => remindAt(a) - remindAt(b));
    }
    // the days from k on that have anything, each with what it has (and the
    // tasks with no date, last)
    function agenda(k: string, days: int): var {
        const last = addDays(k, days);
        const out = [];
        const dated = items.filter(it => it.date !== "" && it.date >= k && it.date < last && !(it.kind === "task" && it.done && it.date < today()));
        const byDay = {};
        for (const it of dated) (byDay[it.date] = byDay[it.date] || []).push(it);
        for (const d of Object.keys(byDay).sort())
            out.push({ day: d, items: byDay[d].sort((a, b) => when(a).localeCompare(when(b))) });
        const open = items.filter(it => it.date === "" && !(it.kind === "task" && it.done));
        if (open.length) out.push({ day: "", items: open });
        return out;
    }
    // tasks: not done first (by due date), then done
    function tasks(): var {
        return items.filter(it => it.kind === "task")
            .sort((a, b) => (a.done - b.done) || when(a).localeCompare(when(b)) || a.title.localeCompare(b.title));
    }
    function find(id: string): var { return items.find(it => it.id === id) ?? null; }

    // ---------------------------------------------------------------- changing
    function newId(): string { return Date.now().toString(36) + Math.floor(Math.random() * 1e6).toString(36); }
    function changed(): void { rev++; save.restart(); }
    function add(it: var): string {
        const x = Object.assign({ id: newId(), kind: "event", title: "", date: "", time: "", done: false, remind: -1, fired: false }, it);
        x.fired = x.remind >= 0 && startAt(x) < Date.now();      // (it has been: no reminder for it)
        items = items.concat([x]);
        changed();
        return x.id;
    }
    function update(id: string, ch: var): void {
        items = items.map(it => {
            if (it.id !== id) return it;
            const x = Object.assign({}, it, ch);
            if ("date" in ch || "time" in ch || "remind" in ch) x.fired = x.remind >= 0 && startAt(x) < Date.now();
            return x;
        });
        changed();
    }
    function remove(id: string): void { items = items.filter(it => it.id !== id); changed(); }
    function toggle(id: string): void { const it = find(id); if (it) update(id, { done: !it.done }); }

    function addNote(): string {
        const n = { id: newId(), title: "", body: "", updated: Date.now() };
        notes = [n].concat(notes);
        changed();
        return n.id;
    }
    function updateNote(id: string, title: string, body: string): void {
        if (id === "guide") return;
        notes = notes.map(n => n.id === id ? Object.assign({}, n, { title: title, body: body, updated: Date.now() }) : n)
            .sort((a, b) => b.updated - a.updated);
        changed();
    }
    function removeNote(id: string): void { if (id === "guide") return; notes = notes.filter(n => n.id !== id); changed(); }
    function note(id: string): var { return id === "guide" ? guide : notes.find(n => n.id === id) ?? null; }

    // the theme's guide: a note of its own, first in NOTES, read-only, renewed
    // with every update (widgets/organizer/guide.txt)
    property var guide: null
    FileView {
        path: Quickshell.shellPath("widgets/organizer/guide.txt")
        watchChanges: true
        onFileChanged: reload()
        printErrors: false
        onLoaded: { root.guide = { id: "guide", title: "Magnetic 88 — Guide", body: text(), updated: 0, pinned: true }; root.rev++; }
    }

    // ---------------------------------------------------------------- reminders
    // when it rings (ms): its time less its reminder; with no time, at 9:00
    function remindAt(it: var): real {
        const d = parse(it.date);
        if (isNaN(d)) return Infinity;
        const m = /^(\d{1,2}):(\d{2})$/.exec(it.time || "");
        d.setHours(m ? +m[1] : 9, m ? +m[2] : 0, 0, 0);
        return d.getTime() - Math.max(0, it.remind) * 60000;
    }
    // when it is (ms): its time, or 9:00 on its day
    function startAt(it: var): real { return remindAt(Object.assign({}, it, { remind: 0 })); }
    function remindText(r: int): string {
        if (r < 0) return "NONE";
        if (r === 0) return "AT THE TIME";
        if (r < 60) return r + " MIN BEFORE";
        if (r < 1440) return (r / 60) + (r === 60 ? " HOUR" : " HOURS") + " BEFORE";
        return (r / 1440) + (r === 1440 ? " DAY" : " DAYS") + " BEFORE";
    }
    readonly property var remindSteps: [-1, 0, 5, 10, 15, 30, 60, 120, 1440, 2880]
    Timer {
        interval: 15000
        repeat: true
        running: root.loaded
        triggeredOnStart: true
        onTriggered: {
            const now = Date.now();
            let any = false;
            const next = root.items.map(it => {
                if (it.remind < 0 || it.fired || it.done) return it;
                const at = root.remindAt(it);
                if (at > now) return it;
                // (missed by more than a day, the machine off: let go quietly)
                if (now - at < 86400000) {
                    const what = (it.time ? it.time + "  ·  " : "") + root.dayLabel(it.date);
                    Quickshell.execDetached(["notify-send", "--app-name=Organizer", "--icon=x-office-calendar",
                                             it.title || (it.kind === "task" ? "Task" : "Event"), what]);
                }
                any = true;
                return Object.assign({}, it, { fired: true });
            });
            if (any) { root.items = next; root.changed(); }
        }
    }

    // ---------------------------------------------------------------- kept
    readonly property string file: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state"))
        + "/ultra/retro-futurism/organizer.json"
    FileView {
        id: store
        path: root.file
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.items = (d.items ?? []).filter(it => it && it.id);
                root.notes = (d.notes ?? []).filter(n => n && n.id);
            } catch (e) {}
            root.loaded = true;
            root.rev++;
        }
        onLoadFailed: { root.loaded = true; root.rev++; }
    }
    Timer {
        id: save
        interval: 500
        onTriggered: store.setText(JSON.stringify({ items: root.items, notes: root.notes }, null, 1))
    }
    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", root.file.replace(/\/[^/]*$/, "")])
}
