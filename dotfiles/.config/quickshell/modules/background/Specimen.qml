import QtQuick
import QtQuick.Effects
import Quickshell.Io
import Qt5Compat.GraphicalEffects
import qs.theme
import qs.services
import qs.components

// The month's pressed specimen, in the empty bottom-left corner of the
// sheet: a different one each month, held by a strip of tape, its name
// typed under it (assets/specimens: tools/import_specimens.py, the names in
// specimens.json). At night it is printed pale, like the sheet.
//
// It can be handled:
//   hover         its free edge lifts off the sheet
//   drag          it peels off its tape (the tape stays on the sheet) and
//                 sways as it is carried; let go, it drifts down where it is
//                 and the tape comes over to hold it again
//   double-click  back to its place
//   click         the set of twelve fans out of the corner, January to
//                 December; a click on one lays it here instead (until the
//                 month turns), a click on the sheet folds them away
//   right-click   this month's again
Item {
    id: root

    required property real sheetH

    readonly property string monthKey: Qt.formatDate(Clock.now, "yyyy-MM")
    readonly property int thisMonth: Clock.now.getMonth()        // 0 = January
    property int chosen: -1             // a month picked from the set
    property string chosenIn: ""        // the month it was picked in: it lapses with it
    readonly property int month: chosen >= 0 && chosenIn === monthKey ? chosen : thisMonth
    property var names: []
    readonly property var entry: names[month] ?? null
    property bool fanned: false

    function source(i: int): url {
        return Qt.resolvedUrl("../../assets/specimens/" + String(i + 1).padStart(2, "0") + ".png");
    }
    function choose(i: int): void {
        chosen = i === thisMonth ? -1 : i;
        chosenIn = monthKey;
        fanned = false;
        pick.setText(chosen < 0 ? "" : chosen + " " + chosenIn + "\n");
        piece.goHome();
    }

    FileView {
        path: Qt.resolvedUrl("../../assets/specimens/specimens.json").toString().replace("file://", "")
        onLoaded: { try { root.names = JSON.parse(text()); } catch (e) {} }
    }
    // the month picked from the set, kept over a restart: "<0-11> <yyyy-MM>"
    FileView {
        id: pick
        path: Settings.stateHome + "/archive/specimen"
        printErrors: false
        onLoaded: {
            const f = text().trim().split(" ");
            if (f.length === 2) { root.chosen = Number(f[0]); root.chosenIn = f[1]; }
        }
    }

    // ------------------------------------------------------------ the specimen
    Image {
        id: art
        height: Math.round(root.sheetH * 0.215)
        width: sourceSize.height > 0 ? Math.round(height * sourceSize.width / sourceSize.height) : 0
        source: root.source(root.month)
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
        mipmap: true
        visible: false
    }

    // the tape: on the specimen while it lies, left on the sheet when it is
    // peeled off, and brought over once it is laid down again
    Tape {
        id: tape
        width: Math.max(54, art.width * 0.42)
        height: 18
        rotation: 9 + (piece.peeled ? -5 : 0)
        seed: 77 + root.month
        z: 2
        visible: piece.visible
        opacity: piece.peeled ? 0.8 : 1
        readonly property real onX: piece.x + art.width * 0.5 - width / 2
        readonly property real onY: piece.y + art.height * 0.62
        property bool stuck: false      // left on the sheet while the specimen is carried
        property real restX: 0
        property real restY: 0
        property bool moving: false
        x: stuck ? restX : onX
        y: stuck ? restY : onY
        Behavior on x { enabled: tape.moving; NumberAnimation { duration: 420; easing.type: Easing.InOutCubic } }
        Behavior on y { enabled: tape.moving; NumberAnimation { duration: 420; easing.type: Easing.InOutCubic } }
        Behavior on rotation { NumberAnimation { duration: 260 } }
        // where it stays while the specimen is away
        function stay(): void { restX = onX; restY = onY; stuck = true; }
        // over to hold it again
        function follow(): void {
            moving = true;
            stuck = false;
            settle.restart();
        }
        Timer { id: settle; interval: 460; onTriggered: tape.moving = false }
    }

    Item {
        id: piece
        readonly property real homeX: 72
        readonly property real homeY: root.sheetH - 74 - art.height       // below the desk terminal, above the bar
        property bool peeled: false     // off its tape, being carried
        property bool returning: false
        property real sway: 0           // degrees, from how it is carried
        readonly property real lift: drag.active ? 1 : hover.hovered ? 0.35 : 0
        property real shown: lift
        Behavior on shown { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

        visible: art.status === Image.Ready
        x: homeX
        y: homeY
        z: 3
        width: art.width
        height: art.height
        rotation: -4 + sway - 1.5 * shown
        scale: 1 + 0.05 * shown
        transformOrigin: Item.Bottom
        Behavior on sway { SpringAnimation { spring: 2.4; damping: 0.14; epsilon: 0.05 } }
        Behavior on x { enabled: piece.returning; NumberAnimation { duration: 520; easing.type: Easing.InOutCubic } }
        Behavior on y { enabled: piece.returning; NumberAnimation { duration: 520; easing.type: Easing.InOutCubic } }

        function goHome(): void {
            returning = true;
            x = Qt.binding(() => piece.homeX);
            y = Qt.binding(() => piece.homeY);
            home.restart();
        }
        Timer { id: home; interval: 560; onTriggered: piece.returning = false }

        // by day as drawn; by night a pale print of it; its shadow on the
        // sheet grows as it lifts
        Item {
            id: ink
            anchors.fill: parent
            layer.enabled: piece.shown > 0.01
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Theme.shadow
                blurMax: 32
                shadowBlur: 0.25 + 0.55 * piece.shown
                shadowHorizontalOffset: 1 + 6 * piece.shown
                shadowVerticalOffset: 2 + 12 * piece.shown
                shadowOpacity: 0.25 + 0.45 * piece.shown
            }
            Image { anchors.fill: parent; source: art.source; mipmap: true; smooth: true; opacity: 1 - Theme.night }
            ColorOverlay { anchors.fill: parent; source: art; color: Qt.rgba(0.85, 0.89, 0.95, 0.85); opacity: Theme.night; visible: Theme.night > 0.01 }
        }

        HoverHandler { id: hover; cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor }
        DragHandler {
            id: drag
            target: piece
            xAxis.minimum: 0
            xAxis.maximum: Math.max(0, piece.parent.width - piece.width)
            yAxis.minimum: 0
            yAxis.maximum: Math.max(0, root.sheetH - piece.height)
            onActiveChanged: {
                if (active) {
                    root.fanned = false;
                    piece.returning = false;
                    tape.stay();
                    piece.peeled = true;
                } else {
                    piece.sway = 0;             // it settles with a wobble
                    piece.peeled = false;
                    tape.follow();
                }
            }
            // carried, it leans into the way it goes
            onCentroidChanged: if (active) piece.sway = Math.max(-14, Math.min(14, centroid.velocity.x / 90))
        }
        TapHandler {
            // a double-click is not also a click
            exclusiveSignals: TapHandler.SingleTap | TapHandler.DoubleTap
            onSingleTapped: root.fanned = !root.fanned
            onDoubleTapped: { root.fanned = false; piece.goHome(); tape.follow(); }
        }
        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: { root.choose(root.thisMonth); tape.follow(); }
        }

        InkText {
            visible: root.entry !== null
            x: 4
            y: art.height + 10
            text: root.entry ? root.entry.month + "  " + root.entry.latin + "." : ""
            font.pixelSize: 14
            font.italic: true
            color: Theme.soft
            rotation: 2
        }
    }

    // ------------------------------------------------------------ the set of twelve
    // Slips fanned out of the corner along an arc, January nearly upright,
    // December lying to the right; each slides out a moment after the last.
    Item {
        id: fan
        anchors.fill: parent
        z: 4
        property real open: root.fanned ? 1 : 0
        Behavior on open { NumberAnimation { duration: 560; easing.type: Easing.OutCubic } }
        visible: open > 0.005

        // a click on the bare sheet folds them away
        MouseArea {
            anchors.fill: parent
            enabled: root.fanned
            onClicked: root.fanned = false
        }

        property int hot: -1            // the slip under the pointer
        readonly property real px: piece.homeX + 70
        readonly property real py: root.sheetH - 40

        Repeater {
            model: fan.visible ? 12 : 0

            Item {
                id: slip
                required property int index
                readonly property real angle: -100 + index * 8.2           // degrees: -100 (up) .. -10 (right)
                readonly property real radius: 260
                readonly property real t: Math.max(0, Math.min(1, fan.open * 1.5 - index * 0.04))
                readonly property bool here: index === root.month
                readonly property real a: angle * Math.PI / 180

                width: 92
                height: 128
                x: fan.px + Math.cos(a) * radius * t - width / 2
                y: fan.py + Math.sin(a) * radius * t - height / 2
                rotation: (angle + 90) * t
                opacity: Math.min(1, t * 3)
                z: over.hovered ? 30 : index
                scale: over.hovered ? 1.22 : 1
                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                Rectangle {
                    id: paper
                    anchors.fill: parent
                    color: Theme.paperCard
                    border.color: Theme.rimTop
                    border.width: 1
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: Theme.shadow
                        blurMax: 16
                        shadowBlur: over.hovered ? 0.6 : 0.3
                        shadowVerticalOffset: over.hovered ? 6 : 2
                        shadowHorizontalOffset: 1
                        shadowOpacity: 0.5
                    }
                    Image {
                        id: thumb
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 8
                        width: parent.width - 16
                        height: parent.height - 34
                        source: root.source(slip.index)
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        smooth: true
                        mipmap: true
                        sourceSize.height: 240
                        opacity: 1 - 0.85 * Theme.night
                    }
                    InkText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 6
                        text: root.names[slip.index]?.month ?? ""
                        font.pixelSize: 12
                        color: slip.here ? Theme.madder : Theme.soft
                    }
                    // the one lying in the corner now: a short madder rule
                    Rectangle {
                        visible: slip.here
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 4
                        width: 18
                        height: 1.5
                        color: Theme.madder
                    }
                }

                HoverHandler {
                    id: over
                    cursorShape: Qt.PointingHandCursor
                    onHoveredChanged: {
                        if (hovered) fan.hot = slip.index;
                        else if (fan.hot === slip.index) fan.hot = -1;
                    }
                }
                // the slip on top takes the click for itself (they overlap)
                TapHandler {
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: { root.choose(slip.index); tape.follow(); }
                }
            }
        }

        // the hovered one's name, typed above the fan
        InkText {
            readonly property var e: fan.hot >= 0 ? root.names[fan.hot] ?? null : null
            x: 40
            y: fan.py - 260 - 110
            visible: e !== null
            opacity: fan.open
            text: e ? e.month + "  " + e.latin + ".  " + e.common : ""
            font.pixelSize: 14
            font.italic: true
            color: Theme.soft
        }
    }
}
