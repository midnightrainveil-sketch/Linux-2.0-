pragma Singleton
import QtQml
QtObject {
    id: h
    signal rawEvent(var event)
    property bool usingLua: true
    property var toplevels: ({ values: harness.windows.map(w => ({ address: w.address, title: w.title, lastIpcObject: w })) })
    property var activeToplevel: toplevels.values[0] ?? null
    property var workspaces: ({ values: [
        { id: 1, urgent: false, hasFullscreen: false, toplevels: h.toplevels },
        { id: 3, urgent: false, hasFullscreen: false, toplevels: ({ values: [1] }) } ] })
    property var focusedMonitor: ({ name: Qt.application.screens[0].name, x: 0, y: 0, activeWorkspace: workspaces.values[0] })
    function dispatch(s) { harness.note("dispatch: " + s); }
    function refreshWorkspaces() {}
    function refreshToplevels() {}
}
