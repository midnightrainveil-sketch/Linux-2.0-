import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.services

// The notifications' pager (art/Notification.png): the KAZE personal message
// receiver. A notification arrives: it slides in from the top right corner,
// shows it on its e-ink screen, and slides out again after a while (an urgent
// one stays; it waits while the pointer is on it).
//
//   a tap on the screen   opens what it is about (right-click: clears it)
//   CLEAR                 clears the one shown (the next one shows)
//   ALL CLR               clears them all
//   ◀ ▶                  the newer / older ones on its history
//   Super + N             brings it up to look through them (keys: the
//                         arrows, Enter opens, Delete clears, Shift +
//                         Delete clears all, Esc puts it away)
//
// Placed in the mock-up's own pixels (its body.png starts at the mock-up's
// 36, 128; tools/make_pager.py) and scaled once.
PanelWindow {
    id: win

    readonly property real k: 0.32
    readonly property real bodyW: 1920 * k
    readonly property real bodyH: 584 * k

    anchors { top: true; right: true }
    margins.top: Panels.mailY - 8
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: bodyW + Theme.edge - 10
    implicitHeight: bodyH + 24
    color: "transparent"
    visible: shown || slide.running || p > 0.001
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "retro-futurism-pager"
    WlrLayershell.keyboardFocus: browsing && shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    // (only the pager takes the pointer, not the clear margin round it)
    mask: Region { item: device }

    // ---- what it shows
    property bool shown: false
    property bool browsing: false          // brought up by hand (Super + N)
    property int idx: 0                    // which, on the history (0 the newest)
    readonly property int count: Notifs.count
    readonly property var cur: count > 0 ? Notifs.entries[Math.max(0, Math.min(idx, count - 1))] : null

    // 0 away (off the top right corner), 1 in place
    property real p: shown ? 1 : 0
    Behavior on p {
        NumberAnimation {
            id: slide
            duration: win.shown ? 420 : 260
            easing.type: win.shown ? Easing.OutBack : Easing.InCubic
            easing.overshoot: 0.9
        }
    }

    // how far it has been swiped to the right
    property real swipe: 0
    NumberAnimation { id: swipeBack; target: win; property: "swipe"; to: 0; duration: 200; easing.type: Easing.OutCubic }
    SequentialAnimation {
        id: swipeOut
        NumberAnimation { target: win; property: "swipe"; to: win.bodyW + Theme.edge + 60; duration: 180; easing.type: Easing.OutQuad }
        ScriptAction { script: { win.shown = false; win.browsing = false; hold.stop(); } }
    }
    onPChanged: if (p <= 0.001 && !swipeOut.running) swipe = 0

    function show(i: int, byHand: bool): void {
        swipeOut.stop(); swipe = 0;
        idx = i;
        browsing = byHand;
        shown = true;
        hold.restart();
        flash.restart();
    }
    function hide(): void { shown = false; browsing = false; hold.stop(); }
    function go(d: int): void {
        if (count === 0) return;
        const i = Math.max(0, Math.min(count - 1, idx + d));
        if (i !== idx) { idx = i; flash.restart(); }
        hold.restart();
    }
    function clearOne(): void {
        if (!cur) return;
        Notifs.remove(cur.key);
        hold.restart();
    }
    function clearAll(): void { Notifs.clearAll(); hide(); }
    function openIt(): void {
        if (!cur) { hide(); return; }
        Notifs.open(cur.key);
        hide();
    }

    Connections {
        target: Notifs
        function onArrived(key: int): void {
            if (Scene.locked) return;
            win.show(Math.max(0, Notifs.indexOfKey(key)), win.browsing && win.shown);
        }
        function onEntriesChanged(): void {
            if (win.count === 0 && win.shown && !win.browsing) win.hide();
            else if (win.idx >= win.count) win.idx = Math.max(0, win.count - 1);
        }
    }
    // Super + N, and the old IPC (notifications clear / dnd) in shell.qml
    Connections {
        target: Panels
        function onPagerRequested(): void { if (win.shown && win.browsing) win.hide(); else win.show(0, true); }
    }

    // it goes on its own after a while (an urgent one stays), not while the
    // pointer is on it
    Timer {
        id: hold
        interval: win.browsing ? 15000 : 6500
        running: win.shown && !hover.hovered && !(win.cur?.urgent && !win.browsing)
        onTriggered: win.hide()
    }

    Item {
        id: device
        width: win.bodyW; height: win.bodyH
        // in from the top right corner, back out the same way
        // in from the right edge and back out the same way, straight across;
        // swiped to the right, it goes at once (and its notifications stay)
        x: (win.width - Theme.edge + 10 - width) + (1 - win.p) * (width + Theme.edge + 40) + win.swipe
        y: 12
        opacity: Math.min(1, win.p * 3)
        focus: true

        HoverHandler { id: hover }
        DragHandler {
            id: swiper
            target: null
            xAxis.enabled: true; yAxis.enabled: false
            onTranslationChanged: if (active) win.swipe = Math.max(-12, translation.x)
            onActiveChanged: {
                if (active) { swipeBack.stop(); return; }
                if (win.swipe > device.width * 0.22) swipeOut.restart();
                else swipeBack.restart();
            }
        }

        Keys.onPressed: e => {
            switch (e.key) {
            case Qt.Key_Escape: win.hide(); break;
            case Qt.Key_Left: case Qt.Key_Up: win.press("prev"); win.go(-1); break;
            case Qt.Key_Right: case Qt.Key_Down: win.press("next"); win.go(1); break;
            case Qt.Key_Return: case Qt.Key_Enter: case Qt.Key_Space: win.openIt(); break;
            case Qt.Key_Delete: case Qt.Key_Backspace:
                if (e.modifiers & Qt.ShiftModifier) { win.press("all"); win.clearAll(); }
                else { win.press("clear"); win.clearOne(); }
                break;
            default: return;
            }
            e.accepted = true;
        }

        Item {
            id: unit
            width: 1920; height: 584
            scale: win.k
            transformOrigin: Item.TopLeft
            function ax(x) { return x - 36; }
            function ay(y) { return y - 128; }

            Image {
                anchors.fill: parent
                source: Quickshell.shellPath("assets/pager/body.png")
                smooth: true; mipmap: true
            }

            // ---- the e-ink screen
            Item {
                id: paper
                x: unit.ax(121); y: unit.ay(211); width: 1568; height: 324
                readonly property color ink: "#363736"
                // (its coordinates below are the mock-up's, less its corner)
                function px(x) { return x - 121; }
                function py(y) { return y - 211; }

                component Ink: Text {
                    color: paper.ink
                    font.family: "Inter"
                    font.weight: Font.DemiBold
                    renderType: Text.QtRendering
                }

                Item {
                    id: page
                    anchors.fill: parent
                    visible: win.cur !== null

                    // the app's mark, in ink: a one-colour icon as a solid shape,
                    // a coloured one in greys
                    Item {
                        x: paper.px(176); y: paper.py(226); width: 112; height: 84
                        // (a brand mark or a one-colour icon: drawn as it is, in ink)
                        readonly property bool symbolic: /symbolic|\/marks\//.test(win.cur?.icon ?? "")
                        Image {
                            id: logo
                            anchors.centerIn: parent
                            width: 84; height: 84
                            source: win.cur?.icon ?? ""
                            sourceSize: Qt.size(168, 168)
                            fillMode: Image.PreserveAspectFit
                            smooth: true; mipmap: true
                            visible: parent.symbolic && status === Image.Ready
                            opacity: 0.84
                        }
                        // a coloured icon: in greys, its contrast raised
                        MultiEffect {
                            source: logo
                            anchors.fill: logo
                            visible: !parent.symbolic && logo.status === Image.Ready
                            saturation: -1
                            brightness: -0.12
                            contrast: 0.55
                        }
                        // no icon: its first letter, in a ring
                        Rectangle {
                            visible: logo.status !== Image.Ready
                            anchors.centerIn: parent
                            width: 80; height: 80; radius: 40
                            color: "transparent"
                            border.width: 7; border.color: paper.ink
                            Ink {
                                anchors.centerIn: parent
                                text: ((win.cur?.app || win.cur?.summary || "?").trim().charAt(0) || "?").toUpperCase()
                                font.pixelSize: 46; font.weight: Font.Bold
                            }
                        }
                    }
                    Ink {
                        x: paper.px(325); y: paper.py(270) - height / 2
                        width: paper.px(1380) - x
                        elide: Text.ElideRight
                        text: (win.cur?.app || "Notice").toUpperCase()
                        font.pixelSize: 62; font.letterSpacing: 2
                    }
                    Ink {
                        x: paper.px(1632) - width; y: paper.py(270) - height / 2
                        font.pixelSize: 62; font.weight: Font.Medium; font.letterSpacing: 1
                        text: {
                            const t = win.cur?.time ?? 0;
                            if (!t) return "";
                            const d = new Date(t), now = new Date();
                            const hm = Qt.formatTime(d, "hh:mm");
                            if (d.toDateString() === now.toDateString()) return hm;
                            if (now - d < 6 * 86400000) return Qt.formatDate(d, "ddd").toUpperCase() + " " + hm;
                            return Qt.formatDate(d, "dd/MM");
                        }
                    }
                    Rectangle { x: paper.px(160); y: paper.py(320); width: 1490; height: 3; color: paper.ink }

                    // what it says: who / what, and its message
                    Ink {
                        x: paper.px(166); y: paper.py(336); width: 1484; height: 116
                        verticalAlignment: Text.AlignVCenter
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        fontSizeMode: Text.Fit
                        minimumPixelSize: 44
                        font.pixelSize: 72
                        font.weight: Font.DemiBold
                        lineHeight: 0.95
                        text: {
                            const s = win.cur?.summary ?? "", b = win.cur?.body ?? "";
                            return s && b ? s + ": " + b : (s || b);
                        }
                    }

                    // where on the history: five marks (the one shown filled), and the count
                    Row {
                        x: paper.px(1283); y: paper.py(484)
                        spacing: 6
                        readonly property int at: win.count <= 5 ? win.idx : Math.round(win.idx * 4 / Math.max(1, win.count - 1))
                        Repeater {
                            model: 5
                            Rectangle {
                                required property int index
                                width: 31; height: 15
                                color: index === parent.at ? paper.ink : "transparent"
                                border.width: 4; border.color: paper.ink
                                opacity: index < win.count ? 1 : 0.35
                            }
                        }
                    }
                    Ink {
                        x: paper.px(1640) - width; y: paper.py(486) - height / 2
                        font.pixelSize: 46; font.weight: Font.Medium; font.letterSpacing: 1
                        readonly property int w: Math.max(2, String(win.count).length)
                        text: String(win.idx + 1).padStart(w, "0") + " / " + String(win.count).padStart(w, "0")
                    }
                }
                // nothing on it
                Ink {
                    anchors.centerIn: parent
                    visible: win.cur === null
                    text: Notifs.dnd ? "DO NOT DISTURB  ·  NO MESSAGES" : "NO MESSAGES"
                    font.pixelSize: 58; font.letterSpacing: 6; font.weight: Font.Medium
                    opacity: 0.8
                }

                // an e-ink screen redraws with a quick dark flash
                Rectangle {
                    id: ghost
                    anchors.fill: parent
                    radius: 16
                    color: paper.ink
                    opacity: 0
                    SequentialAnimation on opacity {
                        id: flash
                        running: false
                        NumberAnimation { to: 0.78; duration: 70 }
                        NumberAnimation { to: 0.0; duration: 170; easing.type: Easing.OutQuad }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: win.cur ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: e => {
                        if (e.button === Qt.RightButton) win.clearOne();
                        else win.openIt();
                    }
                }
            }

            // ---- its lamp: lit while it has messages, a pulse as one arrives
            Rectangle {
                id: lamp
                x: unit.ax(935) - 10; y: unit.ay(602) - 10; width: 20; height: 20; radius: 10
                color: "#b7f07a"
                opacity: win.count > 0 ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }
                Rectangle {
                    anchors.centerIn: parent
                    width: 46; height: 46; radius: 23
                    z: -1
                    color: "#9be05a"
                    opacity: 0.28
                    SequentialAnimation on scale {
                        running: win.shown && win.count > 0
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.8; to: 1.25; duration: 900; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 1.25; to: 0.8; duration: 900; easing.type: Easing.InOutSine }
                    }
                }
            }

            // ---- its keys
            component Key: Image {
                id: key
                property string name
                property var at                    // its top left
                signal hit()
                readonly property bool down: area.pressed || win.tapped === name
                source: Quickshell.shellPath("assets/pager/key-" + name + ".png")
                x: unit.ax(at[0]); y: unit.ay(at[1]) + (down ? 4 : 0)
                smooth: true; mipmap: true
                Rectangle {
                    anchors.fill: parent; radius: 14
                    color: "black"; opacity: key.down ? 0.18 : 0
                }
                MouseArea {
                    id: area
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: key.hit()
                }
            }
            Key { name: "clear"; at: [986, 571]; onHit: win.clearOne() }
            Key { name: "all"; at: [1252, 571]; onHit: win.clearAll() }
            Key { name: "prev"; at: [1547, 567]; onHit: win.go(-1) }
            Key { name: "next"; at: [1716, 567]; onHit: win.go(1) }
        }
    }
    // a key the keyboard pressed, shown down a moment
    property string tapped: ""
    function press(name: string): void { tapped = name; tapTimer.restart(); }
    Timer { id: tapTimer; interval: 150; onTriggered: win.tapped = "" }
    onShownChanged: if (shown) device.forceActiveFocus()
}
