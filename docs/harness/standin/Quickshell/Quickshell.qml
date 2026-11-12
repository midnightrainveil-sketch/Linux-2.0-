pragma Singleton
import QtQml
QtObject {
    readonly property var screens: Qt.application.screens
    function env(name) { return harness.env(name); }
    function execDetached(cmd) { harness.note("exec: " + JSON.stringify(cmd)); }
    function shellPath(p) { return harness.shellDir + "/" + p; }
    function iconPath(name, check) { return ""; }
}
