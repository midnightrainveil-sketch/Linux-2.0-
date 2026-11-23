import QtQml
// A socket, imitated: never connects (no player in the harness).
QtObject {
    property string path
    property bool connected: false
    property var parser
    function write(s) {}
    function flush() {}
}
