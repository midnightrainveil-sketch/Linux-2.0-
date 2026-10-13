pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Correspondence: the notification daemon (replaces mako / dunst).
Singleton {
    id: root

    // Envelopes and letters on screen, newest first. A ListModel so that a
    // new arrival adds one card instead of re-laying every card already on
    // the sheet. Roles: nid, serial, opened (arrives already unfolded).
    readonly property ListModel popups: ListModel {}
    // Unopened letters that were not read in time: the letter tray on the
    // desk corner, newest first (nid, serial).
    readonly property ListModel tray: ListModel {}
    property var byId: ({})
    readonly property var history: server.trackedNotifications.values
    // settings.json "doNotDisturb", unless toggled this session (qs ipc call notifications dnd)
    property var dndOverride: null
    readonly property bool dnd: dndOverride === null ? Settings.doNotDisturb : dndOverride
    function toggleDnd(): void { dndOverride = !dnd; }
    property int received: 0          // running count, used for catalogue numbers

    function isCritical(n: var): bool {
        return n !== null && n !== undefined && n.urgency === NotificationUrgency.Critical;
    }

    function indexIn(model: var, id: int): int {
        for (let i = 0; i < model.count; i++)
            if (model.get(i).nid === id) return i;
        return -1;
    }
    function indexOf(id: int): int { return indexIn(popups, id); }

    function hide(n: var): void {
        if (!n) return;
        const i = indexOf(n.id);
        if (i >= 0) popups.remove(i);
        const t = indexIn(tray, n.id);
        if (t >= 0) tray.remove(t);
    }

    // a read letter is filed: off the desk, and the sender is told it is done
    // with (so a later update with the same id arrives as a new letter)
    function file(n: var): void {
        if (!n) return;
        hide(n);
        try { n.expire(); } catch (e) {}       // already closed by its own action
    }

    // at most four on the desk; an unopened envelope pushed off the bottom
    // goes to the tray rather than vanishing, a read letter is filed
    function trimPopups(): void {
        while (popups.count > 4) {
            const last = popups.get(popups.count - 1);
            const nid = last.nid, serial = last.serial, opened = last.opened;
            popups.remove(popups.count - 1);
            if (!opened && byId[nid] && indexIn(tray, nid) < 0) tray.insert(0, { nid: nid, serial: serial });
        }
    }

    // an unopened envelope goes onto the pile in the letter tray
    function toTray(n: var, serial: int): void {
        if (!n) return;
        const i = indexOf(n.id);
        if (i >= 0) popups.remove(i);
        if (indexIn(tray, n.id) < 0) tray.insert(0, { nid: n.id, serial: serial });
    }

    // the newest letter in the tray comes back up, and opens
    function fromTray(): void {
        if (tray.count === 0) return;
        const t = tray.get(0);
        const nid = t.nid, serial = t.serial;
        tray.remove(0);
        if (!byId[nid]) return;
        popups.insert(0, { nid: nid, serial: serial, opened: true });
        trimPopups();
    }

    function dismiss(n: var): void {
        if (!n) return;
        hide(n);
        try { n.dismiss(); } catch (e) {}      // already closed by its own action
    }

    function clearAll(): void {
        popups.clear();
        tray.clear();
        for (const n of root.history.slice()) n.dismiss();
    }

    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: false
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true;
            root.byId[n.id] = n;
            // after a shell reload the server hands back the letters it kept:
            // they are not new mail, so no envelope and no sound
            if (n.lastGeneration) {
                n.closed.connect(() => root.hide(n));
                return;
            }
            root.received += 1;
            const critical = root.isCritical(n);
            const sound = n.hints["x-archive-sound"];
            if (root.dnd && !critical) return;
            if (root.indexOf(n.id) < 0) {
                root.popups.insert(0, { nid: n.id, serial: root.received, opened: false });
                root.trimPopups();
                n.closed.connect(() => root.hide(n));
            }
            Sounds.play(sound ? sound : (critical ? "urgent" : "message"));
        }
    }
}
