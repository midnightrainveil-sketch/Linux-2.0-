pragma Singleton
import QtQml
QtObject {
    readonly property var applications: ({ values: harness.apps })
    function heuristicLookup(cls) { return harness.apps.find(a => a.id.toLowerCase() === String(cls).toLowerCase()) ?? null; }
    function byId(id) { return heuristicLookup(id); }
}
