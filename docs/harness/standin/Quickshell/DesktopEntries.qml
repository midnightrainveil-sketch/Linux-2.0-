pragma Singleton
import QtQml
QtObject {
    // (each one can be started, as a DesktopEntry can: here it only says so)
    readonly property var apps: harness.apps.map(a => Object.assign({ execute: function () { console.log("launch: " + a.id); } }, a))
    readonly property var applications: ({ values: apps })
    function heuristicLookup(cls) { return apps.find(a => a.id.toLowerCase() === String(cls).toLowerCase()) ?? null; }
    function byId(id) { return heuristicLookup(id); }
}
