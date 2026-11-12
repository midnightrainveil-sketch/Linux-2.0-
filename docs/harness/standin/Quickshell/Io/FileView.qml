import QtQml
QtObject {
    id: f
    property string path
    property bool watchChanges: false
    property bool blockLoading: false
    property bool printErrors: true
    property string _text: ""
    signal loaded()
    signal loadFailed()
    signal fileChanged()
    function text() { return _text; }
    function setText(t) { _text = t; harness.note("write " + path); }
    function reload() {
        const r = harness.readFile(path);
        if (r === null || r === undefined) loadFailed(); else { _text = r; loaded(); }
    }
    onPathChanged: if (path !== "") Qt.callLater(reload)
    Component.onCompleted: if (path !== "") Qt.callLater(reload)
}
