pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Correspondence: the notification daemon (replaces mako / dunst).
Singleton {
    id: root

    // Cards on screen, newest first. A ListModel so that a new arrival adds
    // one card instead of re-laying every card already on the sheet.
    readonly property ListModel popups: ListModel {}
    property var byId: ({})
    readonly property var history: server.trackedNotifications.values
    property bool dnd: Settings.doNotDisturb
    property int received: 0          // running count, used for catalogue numbers

    function isCritical(n: var): bool {
        return n !== null && n !== undefined && n.urgency === NotificationUrgency.Critical;
    }

    function indexOf(id: int): int {
        for (let i = 0; i < popups.count; i++)
            if (popups.get(i).nid === id) return i;
        return -1;
    }

    function hide(n: var): void {
        if (!n) return;
        const i = indexOf(n.id);
        if (i >= 0) popups.remove(i);
    }

    function dismiss(n: var): void {
        if (!n) return;
        hide(n);
        n.dismiss();
    }

    function clearAll(): void {
        popups.clear();
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
            root.received += 1;
            root.byId[n.id] = n;
            const critical = root.isCritical(n);
            const sound = n.hints["x-archive-sound"];
            if (root.dnd && !critical) return;
            if (root.indexOf(n.id) < 0) {
                root.popups.insert(0, { nid: n.id, serial: root.received });
                while (root.popups.count > 4) root.popups.remove(root.popups.count - 1);
                n.closed.connect(() => root.hide(n));
            }
            Sounds.play(sound ? sound : (critical ? "urgent" : "message"));
        }
    }
}
