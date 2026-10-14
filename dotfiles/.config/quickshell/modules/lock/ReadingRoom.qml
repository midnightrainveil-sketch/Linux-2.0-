import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import qs.theme
import qs.services
import qs.components

// Reading Room (lock screen): the sheet with a large Time Record centred and a
// "Signature: ______" field, sealed in wax as it locks. A wrong password
// stamps REJECTED in madder; a right one stamps ADMITTED in blue and breaks
// the seal, then the sheet fades away.
// Lock with:  qs ipc call lock lock   (hypridle and Super+Escape do this)
Scope {
    id: room

    property string buffer: ""
    property string verdict: ""        // "", "admitted", "rejected"
    property bool busy: false
    property int attempt: 0
    property bool leaving: false

    function lock() {
        if (sessionLock.locked) return;
        buffer = "";
        verdict = "";
        leaving = false;
        attempt = 0;
        sessionLock.locked = true;
        Sounds.play("lock");
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
            room.attempt += 1;
            if (result === PamResult.Success) {
                room.verdict = "admitted";
                Sounds.play("login");
                unlockLater.start();
            } else {
                room.verdict = "rejected";
                room.buffer = "";
                Sounds.play("error");
            }
        }
        onError: {
            room.busy = false;
            room.attempt += 1;
            room.verdict = "rejected";
            room.buffer = "";
        }
    }

    // let the ADMITTED stamp land, then fade the sheet away
    SequentialAnimation {
        id: unlockLater
        PauseAnimation { duration: 450 }
        ScriptAction { script: room.leaving = true }
        PauseAnimation { duration: Theme.dur(600) }
        ScriptAction { script: { sessionLock.locked = false; room.buffer = ""; room.verdict = ""; room.leaving = false; } }
    }

    WlSessionLock {
        id: sessionLock
        locked: false

        WlSessionLockSurface {
            id: surface
            color: Theme.paperBase

            Item {
                anchors.fill: parent
                opacity: room.leaving ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: Theme.dur(600); easing.type: Easing.InOutQuad } }

                Grain { anchors.fill: parent; strength: 1.15 }

                // a click anywhere gives the signature line the keyboard
                MouseArea {
                    anchors.fill: parent
                    onPressed: field.forceActiveFocus()
                }

                // header, as on the plate
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height * 0.08
                    spacing: 3
                    InkText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Reading Room"
                        caps: true
                        tracking: 0.16
                        font.pixelSize: 14
                        color: Theme.graphite
                    }
                    InkText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Admission by signature."
                        color: Theme.soft
                    }
                }

                IndexCard {
                    id: card
                    anchors.centerIn: parent
                    width: 600
                    title: Settings.archiveName
                    subtitle: "Time Record."
                    number: Clock.timeRecordNo
                    labelWidth: 134
                    seed: 1001
                    lift: 1.8

                    Item {
                        width: parent.width
                        height: 150
                        // the Time Record's tall typewriter figures, larger
                        InkText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: parent.height / 2 - 0.592 * 112 * Theme.clockStretch / 2 - (0.782 - 0.592) * 112 * Theme.clockStretch
                            text: Clock.hours + ":" + Clock.minutes
                            color: Theme.graphite
                            font.pixelSize: 112
                            font.letterSpacing: 8
                            spread: 1.8
                            transform: Scale { yScale: Theme.clockStretch }
                        }
                    }

                    Rule { width: parent.width; height: implicitHeight; seed: 1002 }

                    DataRow { label: "Date"; value: Clock.longDate; labelWidth: card.labelWidth }
                    DataRow { label: "Reader"; value: Settings.user; labelWidth: card.labelWidth }
                    DataRow {
                        label: "Signature"
                        labelWidth: card.labelWidth
                        rowHeight: 44
                        last: true

                        TextInput {
                            id: field
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            focus: true
                            echoMode: TextInput.Password
                            passwordCharacter: "x"
                            font.family: Theme.typewriter
                            font.pixelSize: 16
                            font.letterSpacing: 3
                            color: Theme.graphite
                            cursorDelegate: Item {}
                            // read-only, not disabled, while it checks: a disabled
                            // field drops the keyboard and never takes it back
                            readOnly: room.busy || room.verdict === "admitted"
                            onTextChanged: room.buffer = text
                            onAccepted: room.submit()
                            Keys.onEscapePressed: room.buffer = ""
                            Component.onCompleted: forceActiveFocus()
                            // the signature line always has the keyboard: when
                            // the room locks, after a verdict, and whenever
                            // anything else takes it
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
                            }
                            Connections {
                                target: room
                                function onBufferChanged() { if (room.buffer === "" && field.text !== "") field.text = ""; }
                            }

                            // block caret, blinking slowly
                            Rectangle {
                                x: field.cursorRectangle.x + 2
                                y: field.cursorRectangle.y + 2
                                width: 9
                                height: field.cursorRectangle.height - 4
                                color: Theme.graphite
                                visible: field.enabled
                                SequentialAnimation on opacity {
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 1; duration: 0 }
                                    PauseAnimation { duration: 500 }
                                    NumberAnimation { to: 0; duration: 0 }
                                    PauseAnimation { duration: 500 }
                                }
                            }
                        }
                        Rule {
                            anchors.left: field.left
                            anchors.right: field.right
                            anchors.top: field.bottom
                            anchors.topMargin: 2
                            height: implicitHeight
                            weight: 1
                            color: field.text.length ? Theme.ruleInk : Theme.ruleFaint
                            seed: 1003
                        }
                    }
                    Item { width: 1; height: 6 }
                }

                // the room's seal, pressed over the card's edge beside the
                // time; the right signature breaks it
                WaxSeal {
                    x: card.x - width / 2 + 8
                    y: card.y + Theme.headerHeight + 62 - height / 2
                    landed: sessionLock.locked
                    cracked: room.verdict === "admitted"
                    seed: 1907
                }

                // the verdict stamp, pressed onto the card's corner
                Stamp {
                    id: verdictStamp
                    visible: room.verdict !== ""
                    kind: "box"
                    word: room.verdict === "admitted" ? "ADMITTED" : "REJECTED"
                    sub: "No. " + Clock.pad(room.attempt, 3)
                    ink: room.verdict === "admitted" ? Theme.accent : Theme.madder
                    seed: 1004 + room.attempt
                    anchors.right: card.right
                    anchors.rightMargin: 26
                    anchors.bottom: card.bottom
                    anchors.bottomMargin: 58
                    scale: 1.15
                    onVisibleChanged: if (visible) press()
                }
                Connections {
                    target: room
                    function onVerdictChanged() { if (room.verdict !== "") verdictStamp.press(); }
                }

                // the plate's name, the one script line on this screen
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height * 0.82
                    visible: Plates.latin !== ""
                    text: Plates.latin
                    font.family: Theme.script
                    font.pixelSize: 30
                    color: Theme.soft
                }
            }
        }
    }
}
