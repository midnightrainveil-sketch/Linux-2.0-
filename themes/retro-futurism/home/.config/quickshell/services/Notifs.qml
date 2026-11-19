pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Notifications (this shell is the notification daemon). The newest three
// show as cards; one goes after eight seconds unless it is urgent.
Singleton {
    id: root

    readonly property ListModel popups: ListModel {}     // nid, at ("02:14")
    property var byId: ({})
    property bool dnd: false
    function toggleDnd(): void { dnd = !dnd; }

    function indexOf(id: int): int {
        for (let i = 0; i < popups.count; i++)
            if (popups.get(i).nid === id) return i;
        return -1;
    }
    function hide(id: int): void {
        const i = indexOf(id);
        if (i >= 0) popups.remove(i);
    }
    function dismiss(n: var): void {
        if (!n) return;
        hide(n.id);
        try { n.dismiss(); } catch (e) {}
    }
    function expire(id: int): void {
        const n = byId[id];
        hide(id);
        try { if (n) n.expire(); } catch (e) {}
    }
    function open(n: var): void {
        if (!n) return;
        const def = (n.actions ?? []).find(a => a.identifier === "default");
        hide(n.id);
        try { if (def) def.invoke(); else n.dismiss(); } catch (e) {}
    }
    function clearAll(): void {
        popups.clear();
        for (const n of server.trackedNotifications.values.slice()) {
            try { n.dismiss(); } catch (e) {}
        }
    }

    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: false
        actionsSupported: true
        imageSupported: false
        persistenceSupported: false

        onNotification: n => {
            n.tracked = true;
            root.byId[n.id] = n;
            n.closed.connect(() => { root.hide(n.id); delete root.byId[n.id]; });
            if (n.lastGeneration) return;
            const urgent = n.urgency === NotificationUrgency.Critical;
            if (root.dnd && !urgent) return;
            if (root.indexOf(n.id) < 0) {
                root.popups.insert(0, { nid: n.id, at: Qt.formatTime(new Date(), "hh:mm"), stays: urgent });
                while (root.popups.count > 3) root.expire(root.popups.get(root.popups.count - 1).nid);
            }
        }
    }
}
