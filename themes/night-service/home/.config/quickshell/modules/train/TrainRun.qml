import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.theme
import qs.services

// A night train along the top of the bar, left to right, above the windows:
// engine and tender, baggage van, two coaches, the dining car and the
// sleeping car (assets/train, tools/import_train.py), steam drifting back
// from the chimney. Only the train itself takes the pointer; everything
// else goes through to what is under it.
//
//   on the rails   it runs along the bar (along the foot of the screen with a
//                  window truly fullscreen), again and again (Trainset)
//   dragged        press and pull: the train follows like a snake, every
//                  carriage along the path of the one before it
//   let go         near the middle of the screen: a screensaver. The desk
//                  goes dark, the train grows large and runs through the
//                  night; a click or a key brings the desk back. Let go
//                  anywhere else, it fades and the next sets off.
PanelWindow {
    id: win

    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "archive-train"
    WlrLayershell.keyboardFocus: mode === "saver" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"
    // the pointer reaches the train only (all of the screen while dragged or
    // dreaming)
    mask: Region { item: win.mode === "rail" ? hitBox : everything }

    property string mode: "rail"              // "rail" | "drag" | "fade" | "saver"
    readonly property real speed: 150         // px a second, on the rails
    readonly property real gap: 1.6           // s between one train and the next
    property var spec: ({ vehicles: [], steam: [] })
    readonly property var cars: (spec.vehicles || []).slice().reverse()   // rear first, left to right
    readonly property real length: cars.reduce((s, v) => s + v.w - 1, 0)
    // each carriage's distance from the rear, and from the front
    readonly property var fromRear: { const o = []; let x = 0; for (const v of cars) { o.push(x); x += v.w - 1; } return o; }
    // the chimney, this far back from the engine's nose
    readonly property real chimneyBack: (cars.length ? cars[cars.length - 1].w : 0) * 0.17

    FileView {
        path: Qt.resolvedUrl("../../assets/train/train.json").toString().replace("file://", "")
        onLoaded: { try { win.spec = JSON.parse(text()); } catch (e) {} }
    }

    // ---------------------------------------------------------------- where the rails are
    // on the bar's top rule; with a window truly fullscreen (the bar hidden
    // under it) along the very foot of the screen
    readonly property real railY: full ? height : height - Theme.barHeight + 3
    property bool full: false
    function checkFull(): void {
        const ws = Hyprland.focusedMonitor?.activeWorkspace;
        if (!ws || !ws.hasFullscreen) { full = false; return; }
        Hyprland.refreshToplevels();
        settleFull.restart();
    }
    Timer {
        id: settleFull
        interval: 150
        onTriggered: {
            const ws = Hyprland.focusedMonitor?.activeWorkspace;
            const tops = ws?.toplevels?.values ?? [];
            // fullscreen 2 is true fullscreen; 1 (maximised) keeps the bar
            const known = tops.filter(t => t.lastIpcObject && t.lastIpcObject.fullscreen !== undefined);
            win.full = known.length ? known.some(t => t.lastIpcObject.fullscreen === 2) : (ws?.hasFullscreen ?? false);
        }
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const n = event.name;
            if (n === "fullscreen" || n.startsWith("workspace") || n === "activewindowv2" || n === "closewindow" || n === "focusedmon") win.checkFull();
        }
    }
    Component.onCompleted: checkFull()

    // ---------------------------------------------------------------- time
    property real t: 0
    property real start: 0
    readonly property real trainX: -length + speed * (t - start)
    FrameAnimation {
        running: Trainset.running && win.length > 0 && win.mode !== "drag"
        onTriggered: {
            win.t += Math.min(frameTime, 0.05);
            if (win.mode === "saver") return;
            if (win.mode !== "rail") return;
            // turned off while the next was still waiting to come on: it does not
            if (!Trainset.on && win.trainX + win.length < 0 && win.t < win.start) { Trainset.running = false; return; }
            // gone off the right edge: another, or the last
            if (win.trainX > win.width) {
                if (Trainset.on) win.start = win.t + win.gap;
                else Trainset.running = false;
            }
        }
    }

    Item { id: everything; anchors.fill: parent }
    // the train's own box on the rails: where the pointer can take it
    Item {
        id: hitBox
        x: win.trainX
        y: win.railY - 60
        width: win.length
        height: 60
    }

    // ---------------------------------------------------------------- the snake
    // the path the train's front has taken while dragged, newest first
    property var trail: []
    property var poses: []
    property point grabOffset: Qt.point(0, 0)
    function pointAt(d: real): point {
        const tr = trail;
        let left = d;
        for (let i = 1; i < tr.length; i++) {
            const a = tr[i - 1], b = tr[i];
            const seg = Math.hypot(b.x - a.x, b.y - a.y);
            if (seg >= left && seg > 0) return Qt.point(a.x + (b.x - a.x) * left / seg, a.y + (b.y - a.y) * left / seg);
            left -= seg;
        }
        const last = tr[tr.length - 1];
        return Qt.point(last.x - left, last.y);   // (past its end: straight on, back to the left)
    }
    function layoutSnake(): void {
        const out = [];
        for (let i = 0; i < cars.length; i++) {
            const dFront = length - fromRear[i] - (cars[i].w - 1);
            const a = pointAt(dFront), b = pointAt(dFront + cars[i].w);
            out.push({ x: (a.x + b.x) / 2, y: (a.y + b.y) / 2, angle: Math.atan2(a.y - b.y, a.x - b.x) * 180 / Math.PI });
        }
        poses = out;
    }
    function grab(px: real, py: real): void {
        const head = Qt.point(trainX + length, railY);
        grabOffset = Qt.point(head.x - px, head.y - py);
        const tr = [];
        for (let d = 0; d <= length + 40; d += 4) tr.push(Qt.point(head.x - d, head.y));
        trail = tr;
        mode = "drag";
        layoutSnake();
    }
    function pull(px: real, py: real): void {
        const head = Qt.point(px + grabOffset.x, py + grabOffset.y);
        const tr = trail;
        if (Math.hypot(head.x - tr[0].x, head.y - tr[0].y) < 3) return;
        tr.unshift(head);
        // keep only as much path as the train needs
        let total = 0, keep = tr.length;
        for (let i = 1; i < tr.length; i++) {
            total += Math.hypot(tr[i].x - tr[i - 1].x, tr[i].y - tr[i - 1].y);
            if (total > length + 60) { keep = i + 1; break; }
        }
        trail = tr.slice(0, keep);
        layoutSnake();
    }
    function letGo(px: real, py: real): void {
        if (px > width * 0.25 && px < width * 0.75 && py > height * 0.18 && py < height * 0.78) dream();
        else leaveRails();
    }
    // (off the rails: it fades away, and the next one sets off from the left)
    function leaveRails(): void { mode = "fade"; fading.restart(); }
    SequentialAnimation {
        id: fading
        NumberAnimation { target: win; property: "fade"; from: 1; to: 0; duration: Theme.dur(420) }
        ScriptAction {
            script: {
                win.mode = "rail";
                win.fade = 1;
                win.start = win.t + win.gap;
                if (!Trainset.on) Trainset.running = false;
            }
        }
    }
    property real fade: 1

    // ---------------------------------------------------------------- the screensaver
    readonly property real big: 3              // how much larger the train runs at night
    property real dark: 0                      // the night falling, 0 to 1
    property real saverStart: 0
    readonly property real saverX: -length * big + speed * 1.6 * (t - saverStart)
    readonly property real saverRail: height * 0.72
    property point enteredAt: Qt.point(0, 0)
    property real enteredT: 0
    function dream(): void {
        mode = "saver";
        saverStart = t;
        enteredT = t;
        nightFalls.restart();
        keys.forceActiveFocus();
    }
    function wake(): void {
        if (mode !== "saver") return;
        dayComes.restart();
    }
    NumberAnimation { id: nightFalls; target: win; property: "dark"; from: 0; to: 1; duration: Theme.dur(900); easing.type: Easing.InOutQuad }
    SequentialAnimation {
        id: dayComes
        NumberAnimation { target: win; property: "dark"; to: 0; duration: Theme.dur(600); easing.type: Easing.InOutQuad }
        ScriptAction { script: { win.mode = "rail"; win.start = win.t + win.gap; if (!Trainset.on) Trainset.running = false; } }
    }
    onTChanged: if (mode === "saver" && saverX > width) saverStart = t + 1.2

    // the night over the desk: it hides the windows
    Item {
        anchors.fill: parent
        visible: win.dark > 0.001
        opacity: win.dark
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: "#0b1426" }
                GradientStop { position: 0.7; color: "#16233d" }
                GradientStop { position: 1; color: "#0e1829" }
            }
        }
        // the moon, and the far mountains under it
        Rectangle {
            x: parent.width * 0.74; y: parent.height * 0.14
            width: 86; height: 86; radius: 43
            color: "#efe8d2"
            opacity: 0.92
        }
        Canvas {
            anchors.fill: parent
            onPaint: {
                const g = getContext("2d");
                g.reset();
                const w = width, h = height, base = win.saverRail;
                g.fillStyle = "rgba(40, 56, 88, 0.85)";
                g.beginPath();
                g.moveTo(0, base);
                const peaks = [[0, 0.62], [0.08, 0.5], [0.17, 0.58], [0.28, 0.42], [0.4, 0.55], [0.52, 0.46], [0.63, 0.57], [0.74, 0.44], [0.86, 0.56], [1, 0.48]];
                for (const [px, py] of peaks) g.lineTo(px * w, py * h);
                g.lineTo(w, base);
                g.closePath();
                g.fill();
                // snow on the peaks
                g.fillStyle = "rgba(222, 228, 240, 0.35)";
                for (let i = 1; i < peaks.length - 1; i++) {
                    const [px, py] = peaks[i];
                    if (py > 0.5) continue;
                    g.beginPath();
                    g.moveTo(px * w - 28, py * h + 22); g.lineTo(px * w, py * h); g.lineTo(px * w + 28, py * h + 22);
                    g.closePath(); g.fill();
                }
                // the rails
                g.fillStyle = "#0a111f";
                g.fillRect(0, base, w, h - base);
                g.strokeStyle = "rgba(190, 200, 220, 0.5)";
                g.lineWidth = 2;
                g.beginPath(); g.moveTo(0, base + 2); g.lineTo(w, base + 2); g.stroke();
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height - 64
            text: "The night train.  Click or press any key to return to the desk."
            font.family: Theme.typewriter
            font.pixelSize: 15
            color: "#b8c2d6"
            opacity: win.t - win.enteredT < 4 ? 0.9 : 0
            Behavior on opacity { NumberAnimation { duration: 900 } }
        }
        MouseArea {
            anchors.fill: parent
            enabled: win.mode === "saver"
            hoverEnabled: true
            cursorShape: Qt.BlankCursor
            onClicked: win.wake()
            onPositionChanged: m => {
                if (win.t - win.enteredT < 1.2) { win.enteredAt = Qt.point(m.x, m.y); return; }
                if (Math.hypot(m.x - win.enteredAt.x, m.y - win.enteredAt.y) > 60) win.wake();
            }
        }
    }
    Item {
        id: keys
        focus: win.mode === "saver"
        Keys.onPressed: e => { win.wake(); e.accepted = true; }
    }

    // ---------------------------------------------------------------- the train
    Repeater {
        model: win.cars
        Image {
            id: car
            required property var modelData
            required property int index
            readonly property real k: win.mode === "saver" ? win.big : 1
            readonly property var pose: win.mode === "drag" || win.mode === "fade" ? win.poses[index] : null
            width: modelData.w * k
            height: modelData.h * k
            transformOrigin: Item.Bottom
            x: pose ? pose.x - width / 2
               : win.mode === "saver" ? win.saverX + win.fromRear[index] * k
               : win.trainX + win.fromRear[index]
            y: (pose ? pose.y : win.mode === "saver" ? win.saverRail : win.railY) - height
               - (pose ? 0 : 0.5 * k + 0.5 * k * Math.sin(win.t * 7 + index * 1.7))
            rotation: pose ? pose.angle : 0
            opacity: win.mode === "fade" ? win.fade : 1
            visible: win.mode !== "saver" || win.dark > 0.2
            source: Qt.resolvedUrl("../../assets/train/" + modelData.name + ".png")
            sourceSize: Qt.size(Math.round(modelData.w * 3), Math.round(modelData.h * 3))
            smooth: true
            mipmap: true
        }
    }

    // ---- the pointer on the train: press and pull
    MouseArea {
        x: hitBox.x; y: hitBox.y; width: hitBox.width; height: hitBox.height
        enabled: win.mode === "rail" || win.mode === "drag"
        cursorShape: win.mode === "drag" ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        preventStealing: true
        onPressed: m => { const p = mapToItem(everything, m.x, m.y); win.grab(p.x, p.y); }
        onPositionChanged: m => { if (pressed) { const p = mapToItem(everything, m.x, m.y); win.pull(p.x, p.y); } }
        onReleased: m => { const p = mapToItem(everything, m.x, m.y); win.letGo(p.x, p.y); }
    }

    // ---------------------------------------------------------------- steam
    // drifting back from the chimney and up, thinning out
    readonly property int puffs: 16
    readonly property real every: 0.14          // s between puffs
    readonly property real life: puffs * every
    Repeater {
        model: win.puffs
        Image {
            required property int index
            readonly property string file: (win.spec.steam || [])[index % Math.max(1, (win.spec.steam || []).length)] || ""
            readonly property bool dreaming: win.mode === "saver"
            readonly property real k: dreaming ? win.big : 1
            // how long ago this puff left the chimney, and where the chimney was then
            readonly property real age: ((win.t - index * win.every) % win.life + win.life) % win.life
            readonly property real bornX: dreaming
                ? win.saverX + win.speed * 1.6 * (-age) + (win.length - win.chimneyBack) * k
                : -win.length + win.speed * (win.t - age - win.start) + win.length - win.chimneyBack
            readonly property real baseY: dreaming ? win.saverRail : win.railY
            readonly property real fr: age / win.life
            visible: file !== "" && Trainset.running && (win.mode === "rail" || (dreaming && win.dark > 0.2))
                     && bornX > -40 * k && (dreaming || win.t - age > win.start)
            source: file !== "" ? Qt.resolvedUrl("../../assets/train/" + file) : ""
            width: (28 + 52 * fr) * k
            height: width
            fillMode: Image.PreserveAspectFit
            smooth: true
            x: bornX - width / 2 - 20 * age * k
            y: baseY - 56 * k - height / 2 - 42 * age * k - 8 * fr * fr * k
            opacity: 0.8 * (1 - fr) * Math.min(1, age * 8)
        }
    }
}
