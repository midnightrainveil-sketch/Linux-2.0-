import QtQml
QtObject {
    id: p
    property var command: []
    property bool running: false
    property var stdout
    signal exited(int code)
    onRunningChanged: if (running) Qt.callLater(run)
    Component.onCompleted: if (running) Qt.callLater(run)
    function run() {
        const out = harness.run(JSON.stringify(command));
        if (stdout && stdout.streamFinished) { stdout.text = out; stdout.streamFinished(); }
        else if (stdout && stdout.read) for (const l of out.split("\n")) if (l !== "") stdout.read(l);
        running = false;
        exited(0);
    }
}
