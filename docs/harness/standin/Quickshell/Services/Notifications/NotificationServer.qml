import QtQml
import QtQuick
QtObject {
    id: s
    property bool keepOnReload; property bool bodySupported; property bool bodyMarkupSupported
    property bool actionsSupported; property bool bodyHyperlinksSupported; property bool imageSupported; property bool persistenceSupported
    property var trackedNotifications: ({ values: [] })
    signal notification(var n)
    property var _in: Connections {
        target: harness
        function onNotify(summary, body, app) { s.send(summary, body, app || "mail"); }
    }
    function send(summary, body, app) {
        const n = { id: Date.now() % 100000 + Math.floor(Math.random() * 1000), appIcon: "", desktopEntry: "", summary: summary, body: body, appName: app, urgency: 1, actions: [], lastGeneration: false,
                    tracked: false, closed: { connect: f => {} }, dismiss: () => {}, expire: () => {} };
        notification(n);
    }
}
