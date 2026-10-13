import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.theme
import qs.services
import qs.components
import "../../components/Rand.js" as Rand

// The Card Catalogue (launcher): a wooden catalogue drawer slides up out of
// the bar, seen from a little above, full of library index cards, one per
// application, filed A to Z. The current card stands upright and readable;
// the cards in front of it are tipped forward, the way a finger riffles a
// drawer, and the cards behind show their typed tabs. Typing goes onto the
// little card in the drawer's brass label holder; cards that stop matching
// drop out of sight. Return takes the card out (it lifts away and the
// program opens) and the drawer slides shut.
//
//   type          narrow the drawer           Return, click the card  open
//   arrows, Tab,  riffle                      click a tab             go to that card
//   scroll, PgUp/PgDn                         Escape, click outside   close
PanelWindow {
    id: win

    readonly property string name: "catalogue"
    readonly property bool shown: Panels.open === name

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "archive-catalogue"
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    color: "transparent"
    visible: shown || slide > 0.001
    // while open the whole screen listens (a click outside closes); while
    // the drawer slides shut, clicks already pass through
    mask: Region { item: win.shown ? catcher : null }

    // ------------------------------------------------------------ the index
    property string query: ""
    property int selected: 0
    property bool launching: false

    readonly property var apps: DesktopEntries.applications.values
        .filter(a => !a.noDisplay)
        .slice()
        .sort((a, b) => a.name.localeCompare(b.name))

    // the matching cards, best first (A to Z when nothing is typed)
    readonly property var results: {
        const q = query.trim().toLowerCase();
        if (q === "") return apps;
        const scored = [];
        for (const a of apps) {
            const n = a.name.toLowerCase();
            const extra = [a.genericName ?? "", (a.keywords ?? []).join(" "), (a.categories ?? []).join(" "), a.id ?? ""].join(" ").toLowerCase();
            let s = 0;
            if (n.startsWith(q)) s = 100;
            else if (n.split(/\s+/).some(w => w.startsWith(q))) s = 80;
            else if (n.includes(q)) s = 60;
            else if (extra.includes(q)) s = 30;
            if (s > 0) scored.push({ a, s });
        }
        scored.sort((x, y) => y.s - x.s || x.a.name.localeCompare(y.a.name));
        return scored.map(x => x.a);
    }
    // where each card stands among the results (by id: the delegates get
    // copies of the entries, so identity cannot be compared)
    function key(app) { return app.id || app.name; }
    readonly property var rankByKey: {
        const m = {};
        results.forEach((a, i) => m[key(a)] = i);
        return m;
    }
    onResultsChanged: selected = 0

    // A short archive word for each application's category.
    function category(app) {
        const c = app.categories ?? [];
        const map = [["WebBrowser", "browser"], ["Network", "correspondence"], ["TerminalEmulator", "terminal"],
                     ["Development", "workshop"], ["Graphics", "plates"], ["AudioVideo", "audio-visual"],
                     ["Audio", "audio"], ["Video", "film"], ["Office", "office"], ["Game", "games"],
                     ["Settings", "instruments"], ["System", "system"], ["Utility", "tools"], ["Education", "study"],
                     ["Science", "science"], ["FileManager", "drawers"]];
        for (const [k, v] of map) if (c.indexOf(k) >= 0) return v;
        return c.length ? c[0].toLowerCase() : "application";
    }

    function riffle(by) {
        if (launching || results.length === 0) return;
        selected = Math.max(0, Math.min(results.length - 1, selected + by));
    }
    function launch() {
        const app = results[selected];
        if (!app || launching) return;
        launching = true;
        app.execute();
        closeAfterLift.restart();
    }
    Timer { id: closeAfterLift; interval: Theme.dur(260); onTriggered: Panels.close() }

    onShownChanged: {
        if (shown) {
            launching = false;
            query = "";
            input.text = "";
            selected = 0;
            standUp.restart();
            input.forceActiveFocus();
        }
    }

    // the cards stand up one after another as the drawer opens
    property int standing: 0
    Timer {
        id: standUp
        interval: Theme.reducedMotion ? 1 : 32
        repeat: true
        onTriggered: { win.standing += 1; if (win.standing > 12) stop(); }
        onRunningChanged: if (running) win.standing = 0
    }

    // ------------------------------------------------------------ motion
    property real slide: shown ? 1 : 0
    Behavior on slide {
        NumberAnimation {
            duration: win.shown ? Theme.dur(520) : Theme.dur(260)
            easing.type: win.shown ? Easing.OutBack : Easing.InCubic
            easing.overshoot: 0.9
        }
    }

    // ------------------------------------------------------------ the room
    Item {
        id: catcher
        anchors.fill: parent
    }
    // the desk dims a little while the drawer is out
    Rectangle {
        anchors.fill: parent
        color: Theme.night > 0.5 ? "#050b16" : "#1e1d22"
        opacity: 0.22 * win.slide
    }
    MouseArea {
        anchors.fill: parent
        onClicked: Panels.close()
        onWheel: wheel => win.riffle(wheel.angleDelta.y > 0 ? -1 : 1)
    }

    HyprlandFocusGrab {
        windows: [win]
        active: win.shown
        onCleared: if (Panels.open === win.name) Panels.close()
    }

    // ------------------------------------------------------------ the drawer
    Item {
        id: stage
        width: 820
        height: 700
        anchors.horizontalCenter: parent.horizontalCenter
        // pulled up out of the bar
        y: win.height - Theme.barHeight - height + 36 + (1 - win.slide) * (height + 40)

        readonly property real frontTop: 520      // the drawer's front lip
        readonly property real cardW: 600
        readonly property real cardH: 360

        MouseArea {
            anchors.fill: parent
            onWheel: wheel => win.riffle(wheel.angleDelta.y > 0 ? -1 : 1)
        }

        // the inside of the drawer: dark wood walls narrowing to the back
        Canvas {
            id: inside
            anchors.fill: parent
            readonly property color wood: Theme.night > 0.5 ? "#101a2b" : "#3a2f27"
            onWoodChanged: requestPaint()
            onPaint: {
                const g = getContext("2d");
                g.reset();
                const f = stage.frontTop;
                g.beginPath();
                const b = f - 330;                    // the back of the drawer
                g.moveTo(40, f); g.lineTo(780, f); g.lineTo(726, b); g.lineTo(94, b); g.closePath();
                const grad = g.createLinearGradient(0, b, 0, f);
                grad.addColorStop(0, String(Qt.darker(wood, 1.6)));
                grad.addColorStop(1, String(wood));
                g.fillStyle = grad;
                g.fill();
                // the side walls catch a little light
                g.fillStyle = Qt.rgba(1, 1, 1, 0.05);
                g.beginPath(); g.moveTo(40, f); g.lineTo(72, f); g.lineTo(116, b); g.lineTo(94, b); g.closePath(); g.fill();
                g.fillStyle = Qt.rgba(0, 0, 0, 0.18);
                g.beginPath(); g.moveTo(780, f); g.lineTo(748, f); g.lineTo(704, b); g.lineTo(726, b); g.closePath(); g.fill();
                // the brass rod that keeps the cards in
                g.strokeStyle = Theme.night > 0.5 ? "#6f7f99" : "#8d7449";
                g.lineWidth = 4;
                g.beginPath(); g.moveTo(80, f - 34); g.lineTo(740, f - 34); g.stroke();
            }
        }

        // the cards
        Repeater {
            model: win.apps

            Item {
                id: slot
                required property var modelData
                required property int index

                readonly property int rank: win.rankByKey[win.key(modelData)] ?? -1
                readonly property int r: rank - win.selected
                readonly property bool wanted: rank >= 0 && r >= -4 && r <= 10 && win.slide > 0.001
                readonly property bool flipped: r < 0
                readonly property bool lifted: win.launching && r === 0
                readonly property int k: Math.max(0, r)                 // depth behind the current card
                readonly property bool stood: k < win.standing || win.standing > 12

                // stay a moment after leaving, so a card can be seen to drop
                property bool alive: false
                onWantedChanged: if (wanted) alive = true; else dropTimer.restart()
                Timer { id: dropTimer; interval: Theme.dur(320); onTriggered: slot.alive = slot.wanted }
                Component.onCompleted: alive = wanted

                visible: alive
                z: flipped ? 600 + (-r) : 500 - k
                width: stage.cardW
                height: stage.cardH
                x: (stage.width - width) / 2
                // standing cards step back and up; tipped ones lie at the front
                y: !wanted ? stage.frontTop + 120
                   : lifted ? -260
                   : flipped ? stage.frontTop + 60 - height + 5 * (-r)
                   : stage.frontTop + 80 - height - 26 * k
                scale: flipped ? 1 : 1 - 0.03 * k
                transformOrigin: Item.Bottom
                opacity: !wanted || lifted ? 0 : (k >= 9 ? 0.55 : 1)

                transform: Rotation {
                    origin.x: slot.width / 2
                    origin.y: slot.height
                    axis { x: 1; y: 0; z: 0 }
                    // leaning back a little; tipped toward you; lying flat until the drawer opens
                    angle: slot.flipped ? 58 + 5 * (-slot.r)
                           : !slot.stood ? 70
                           : slot.lifted ? -2 : -7
                    Behavior on angle { NumberAnimation { duration: Theme.dur(300); easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
                }

                Behavior on y { NumberAnimation { duration: Theme.dur(slot.lifted ? 300 : 260); easing.type: slot.lifted ? Easing.InCubic : Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: Theme.dur(260); easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: Theme.dur(220) } }

                Loader {
                    anchors.fill: parent
                    active: slot.alive
                    sourceComponent: CatalogueCard {
                        app: slot.modelData
                        number: slot.index + 1
                        category: win.category(slot.modelData)
                        tabSlot: slot.index % 3
                        face: slot.r >= 0 && slot.r <= 1
                        current: slot.r === 0
                        shade: slot.flipped ? 0.12 : Math.min(0.5, 0.06 * slot.k) * (Theme.night > 0.5 ? 1.3 : 1)
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.topMargin: -30           // the tab too
                    enabled: slot.wanted && !win.launching
                    cursorShape: Qt.PointingHandCursor
                    onClicked: slot.r === 0 ? win.launch() : (win.selected = slot.rank)
                    onWheel: wheel => win.riffle(wheel.angleDelta.y > 0 ? -1 : 1)
                }
            }
        }

        // nothing under that heading
        InkText {
            visible: win.results.length === 0
            anchors.horizontalCenter: parent.horizontalCenter
            y: stage.frontTop - 70
            text: "No card under that heading."
            color: Theme.night > 0.5 ? Theme.faded : "#d9cdbd"
            font.pixelSize: 17
        }

        // the drawer's front: wood, a brass label holder with the query typed
        // on its card, and a brass cup pull
        Item {
            id: front
            z: 1000
            x: 30
            y: stage.frontTop
            width: 760
            height: 170

            Canvas {
                id: frontWood
                anchors.fill: parent
                readonly property color tone: Theme.night > 0.5 ? "#1a2840" : "#5b4a3b"
                onToneChanged: requestPaint()
                onPaint: {
                    const g = getContext("2d");
                    g.reset();
                    const w = width, h = height;
                    const grad = g.createLinearGradient(0, 0, 0, h);
                    grad.addColorStop(0, String(Qt.lighter(tone, 1.25)));
                    grad.addColorStop(0.08, String(tone));
                    grad.addColorStop(1, String(Qt.darker(tone, 1.25)));
                    g.fillStyle = grad;
                    g.fillRect(0, 0, w, h);
                    // grain: long wavering lines, a little lighter and darker than the wood
                    const r = Rand.make(1907);
                    for (let i = 0; i < 46; i++) {
                        const y0 = r() * h, amp = 1 + r() * 3, len = 80 + r() * 260, freq = 0.004 + r() * 0.01;
                        g.strokeStyle = r() < 0.5 ? Qt.rgba(0, 0, 0, 0.07 + r() * 0.08) : Qt.rgba(1, 1, 1, 0.04 + r() * 0.05);
                        g.lineWidth = 0.6 + r() * 1.2;
                        g.beginPath();
                        const x0 = r() * w;
                        for (let x = 0; x <= len; x += 6) {
                            const yy = y0 + Math.sin((x0 + x) * freq + i) * amp;
                            if (x === 0) g.moveTo(x0 + x, yy); else g.lineTo(x0 + x, yy);
                        }
                        g.stroke();
                    }
                    // the raised panel's edges
                    g.strokeStyle = Qt.rgba(0, 0, 0, 0.35); g.lineWidth = 2; g.strokeRect(18, 16, w - 36, h - 30);
                    g.strokeStyle = Qt.rgba(1, 1, 1, 0.12); g.lineWidth = 1; g.strokeRect(20, 18, w - 40, h - 34);
                    // the lip catching the light
                    g.fillStyle = Qt.rgba(1, 1, 1, 0.16); g.fillRect(0, 0, w, 3);
                }
            }

            // brass label holder
            Rectangle {
                id: holder
                anchors.horizontalCenter: parent.horizontalCenter
                y: 30
                width: 300
                height: 62
                radius: 3
                color: Theme.night > 0.5 ? "#7d8aa1" : "#a68a5b"
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.4)
                // the label card behind the brass frame
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 7
                    color: Theme.paperCard
                    Grain { anchors.fill: parent; strength: 0.9 }

                    InkText {
                        id: queryLabel
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Query:"
                        color: Theme.faded
                        font.pixelSize: 16
                    }
                    TextInput {
                        id: input
                        anchors.left: queryLabel.right
                        anchors.leftMargin: 8
                        anchors.right: count.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        font.family: Theme.typewriter
                        font.pixelSize: 17
                        color: Theme.graphite
                        cursorVisible: false
                        cursorDelegate: Item {}
                        clip: true
                        onTextChanged: win.query = text

                        Keys.onPressed: event => {
                            const ctrl = event.modifiers & Qt.ControlModifier;
                            if (event.key === Qt.Key_Escape) { Panels.close(); event.accepted = true; }
                            else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab || (ctrl && event.key === Qt.Key_N)) { win.riffle(1); event.accepted = true; }
                            else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab || (ctrl && event.key === Qt.Key_P)) { win.riffle(-1); event.accepted = true; }
                            else if (event.key === Qt.Key_PageDown) { win.riffle(5); event.accepted = true; }
                            else if (event.key === Qt.Key_PageUp) { win.riffle(-5); event.accepted = true; }
                            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { win.launch(); event.accepted = true; }
                        }

                        // block caret, blinking slowly
                        Rectangle {
                            x: input.cursorRectangle.x + 1
                            y: input.cursorRectangle.y + 2
                            width: 8
                            height: input.cursorRectangle.height - 4
                            color: Theme.graphite
                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                running: win.shown
                                NumberAnimation { to: 1; duration: 0 }
                                PauseAnimation { duration: 500 }
                                NumberAnimation { to: 0; duration: 0 }
                                PauseAnimation { duration: 500 }
                            }
                        }
                    }
                    InkText {
                        id: count
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: win.results.length ? String(win.selected + 1).padStart(2, "0") + " / " + String(win.results.length).padStart(2, "0") : "00"
                        color: Theme.faded
                        font.pixelSize: 13
                    }
                }
                // two little rivets
                Repeater {
                    model: 2
                    Rectangle {
                        required property int index
                        width: 6; height: 6; radius: 3
                        x: index === 0 ? -9 : holder.width + 3
                        anchors.verticalCenter: parent.verticalCenter
                        color: holder.color
                        border.width: 1
                        border.color: Qt.rgba(0, 0, 0, 0.4)
                    }
                }
            }

            // brass cup pull
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 108
                width: 150
                height: 34
                Canvas {
                    anchors.fill: parent
                    readonly property color brass: Theme.night > 0.5 ? "#7d8aa1" : "#a68a5b"
                    onBrassChanged: requestPaint()
                    onPaint: {
                        const g = getContext("2d");
                        g.reset();
                        const w = width, h = height;
                        // the cup: a half-moon, shaded inside
                        g.beginPath();
                        g.moveTo(10, 6);
                        g.lineTo(w - 10, 6);
                        g.quadraticCurveTo(w - 10, h - 2, w / 2, h - 2);
                        g.quadraticCurveTo(10, h - 2, 10, 6);
                        g.closePath();
                        const grad = g.createLinearGradient(0, 6, 0, h);
                        grad.addColorStop(0, String(Qt.darker(brass, 1.6)));
                        grad.addColorStop(0.6, String(brass));
                        grad.addColorStop(1, String(Qt.lighter(brass, 1.25)));
                        g.fillStyle = grad;
                        g.fill();
                        g.strokeStyle = Qt.rgba(0, 0, 0, 0.45);
                        g.lineWidth = 1;
                        g.stroke();
                        // its mounting plate
                        g.fillStyle = brass;
                        g.fillRect(0, 2, 12, 8);
                        g.fillRect(w - 12, 2, 12, 8);
                    }
                }
            }
        }
    }
}
