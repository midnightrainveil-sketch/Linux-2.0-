import QtQml
// PAM, imitated: it asks for the password, then after a moment takes
// "letmein" and turns anything else away (so the lock screen's checking,
// refusing and letting in can be seen).
QtObject {
    id: pam
    property string configDirectory
    property string config
    property bool responseRequired: false
    property string given: ""
    signal completed(int result)
    signal error()
    function start() { responseRequired = false; responseRequired = true; }
    function respond(s) { given = s; responseRequired = false; answer.restart(); }
    property Timer answer: Timer {
        interval: 600
        onTriggered: pam.completed(pam.given === "letmein" ? 0 : 1)
    }
}
