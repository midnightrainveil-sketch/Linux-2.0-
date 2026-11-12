import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import qs.theme
import qs.services
import qs.components

// The lock screen: the picture, darker, the time in the viewfinder, and a
// line for the password. Lock with:  qs ipc call lock lock
// (Super + Escape and the idle timer do this.)
Scope {
    id: room

    property string buffer: ""
    property string verdict: ""        // "", "ok", "wrong"
    property bool busy: false

    function lock() {
        if (sessionLock.locked) return;
        buffer = "";
        verdict = "";
        sessionLock.locked = true;
    }
    function submit() {
        if (busy || buffer.length === 0) return;
        busy = true;
        verdict = "";
        pam.start();
    }

    PamContext {
        id: pam
        configDirectory: Quickshell.shellPath("pam")
        config: "password.conf"
        onResponseRequiredChanged: {
            if (!responseRequired) return;
            respond(room.buffer);
        }
        onCompleted: result => {
            room.busy = false;
            if (result === PamResult.Success) {
                room.verdict = "ok";
                unlockLater.start();
            } else {
                room.verdict = "wrong";
                room.buffer = "";
            }
        }
        onError: {
            room.busy = false;
            room.verdict = "wrong";
            room.buffer = "";
        }
    }
    Timer { id: unlockLater; interval: 250; onTriggered: { sessionLock.locked = false; room.buffer = ""; room.verdict = ""; } }

    WlSessionLock {
        id: sessionLock
        locked: false

        WlSessionLockSurface {
            id: surface
            color: "#0b0a0b"

            Image {
                anchors.fill: parent
                source: Settings.wallpaper !== "" ? Settings.wallpaper : Settings.art + "/wallpaper.jpg"
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
            Rectangle { anchors.fill: parent; color: "#000000"; opacity: 0.55 }
            MouseArea { anchors.fill: parent; onPressed: field.forceActiveFocus() }

            Corners { x: 27; y: 27; width: parent.width - 54; height: parent.height - 54; arm: 34; weight: 3 }

            Item {
                id: middle
                width: 520; height: 300
                anchors.centerIn: parent
                Corners { anchors.fill: parent; arm: 30; weight: 3; color: room.verdict === "wrong" ? Theme.warn : Theme.ink }

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 34
                    text: "[ " + Clock.day + " ]"
                    font.pixelSize: 17
                    tracking: 2.6
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 70
                    text: Clock.time
                    font.pixelSize: 104
                    tracking: 6
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 208
                    text: room.busy ? "Checking" : room.verdict === "wrong" ? "Not that one" : room.verdict === "ok" ? "Open" : "Locked  ·  " + Settings.user
                    color: room.verdict === "wrong" ? Theme.warn : Theme.dim
                    font.pixelSize: 14
                    tracking: 2
                }
                Rectangle { x: 110; y: 262; width: 300; height: 1; color: Theme.ink }
                TextInput {
                    id: field
                    x: 110; y: 234
                    width: 300
                    horizontalAlignment: TextInput.AlignHCenter
                    focus: true
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    color: Theme.ink
                    font.family: Theme.mono
                    font.pixelSize: 18
                    font.letterSpacing: 4
                    cursorDelegate: Item {}
                    // read-only, not disabled, while it checks: a disabled
                    // field drops the keyboard and never takes it back
                    readOnly: room.busy || room.verdict === "ok"
                    onTextChanged: room.buffer = text
                    onAccepted: room.submit()
                    Keys.onEscapePressed: room.buffer = ""
                    Component.onCompleted: forceActiveFocus()
                    onActiveFocusChanged: if (!activeFocus) refocus.restart()
                    Timer {
                        id: refocus
                        interval: 60
                        onTriggered: if (sessionLock.locked && !field.activeFocus) field.forceActiveFocus()
                    }
                    Connections {
                        target: sessionLock
                        function onLockedChanged() { if (sessionLock.locked) refocus.restart(); }
                    }
                    Connections {
                        target: room
                        function onVerdictChanged() { refocus.restart(); }
                        function onBufferChanged() { if (room.buffer === "" && field.text !== "") field.text = ""; }
                    }
                }
            }
        }
    }
}
