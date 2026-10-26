import QtQuick
import Quickshell.Io
import qs.theme
import qs.services
import qs.components
import "../../components/Rand.js" as Rand

// One page of the field notebook: ruled paper with a margin, the entry's
// heading (number, date, locality) and what was written. A page is a file,
// ~/Documents/Field Notes/0014.md:
//
//     # Field notes No. 14
//     Date: 14 October 2026
//     Locality: Singapore
//
//     (the note)
//
// The flyleaf (number 0) is the notebook's own first page.
Item {
    id: page

    property int number: 1
    property string dir: ""
    property bool editable: false
    property bool leftHand: false            // a left-hand page: the gutter is on its right
    property bool active: true           // load the file

    readonly property bool flyleaf: number <= 0
    readonly property string path: flyleaf || dir === "" ? "" : dir + "/" + String(number).padStart(4, "0") + ".md"

    // what is on it
    property string date: ""
    property string locality: ""
    property string body: ""
    readonly property bool blank: body.trim() === ""

    signal edited()
    signal keyPressed(var event)

    width: 470
    height: 610

    // ---------------------------------------------------------------- the file
    function today(): string { return Qt.formatDate(new Date(), "d MMMM yyyy"); }

    function parse(text: string): void {
        const lines = text.split("\n");
        let d = "", l = "", i = 0;
        if (lines.length && lines[0].startsWith("# Field notes")) {
            i = 1;
            for (; i < lines.length && lines[i].trim() !== ""; i++) {
                const m = lines[i].match(/^(\w+):\s*(.*)$/);
                if (m && m[1] === "Date") d = m[2];
                else if (m && m[1] === "Locality") l = m[2];
            }
            if (i < lines.length) i++;      // the blank line
        }
        page.date = d;
        page.locality = l;
        // (the file ends with one newline more than the note)
        let b = lines.slice(i).join("\n");
        if (b.endsWith("\n")) b = b.slice(0, -1);
        page.body = b;
        // a page just opened is shown as it is; the one being written is
        // left alone when its own save comes back
        const fresh = parsedPath !== path;
        parsedPath = path;
        if ((fresh || !field.activeFocus) && field.text !== b) field.text = b;
    }
    property string parsedPath: ""
    function serialise(): string {
        return "# Field notes No. " + number + "\n"
             + "Date: " + (date || today()) + "\n"
             + "Locality: " + (locality || Settings.placeName) + "\n\n"
             + body + "\n";
    }

    FileView {
        id: file
        path: page.active ? page.path : ""
        blockLoading: true
        printErrors: false
        onLoaded: page.parse(text())
        onLoadFailed: { page.date = ""; page.locality = ""; page.body = ""; page.parsedPath = page.path; field.text = ""; }
    }
    onPathChanged: if (path === "") { date = ""; locality = ""; body = ""; field.text = ""; }

    // written down a moment after the pen stops (and at once when asked)
    function save(): void {
        saver.stop();
        if (!editable || path === "") return;
        if (blank && !file.loaded) return;          // nothing to keep yet
        if (date === "") date = today();
        if (locality === "") locality = Settings.placeName;
        file.setText(serialise());
    }
    Timer { id: saver; interval: 700; onTriggered: page.save() }

    // ---------------------------------------------------------------- the paper
    Rectangle {
        anchors.fill: parent
        color: Theme.paperRaised
    }
    Grain { anchors.fill: parent; strength: 1.2 }

    FontMetrics {
        id: fm
        font.family: Theme.typewriter
        font.pixelSize: 17
    }
    // the rules follow the writing: one under every line of type (measured
    // off a few lines of it, as the editor lays them out)
    TextEdit {
        id: probe
        visible: false
        font: fm.font
        textFormat: TextEdit.PlainText
        text: "x\nx\nx\nx"
    }
    readonly property real lineGap: probe.contentHeight > 0 ? probe.contentHeight / 4 : fm.lineSpacing
    readonly property real bodyTop: 112

    // blue rules, and a red margin, as in any field book
    Canvas {
        anchors.fill: parent
        readonly property color rule: Theme.night > 0.5 ? Qt.rgba(0.66, 0.77, 0.89, 0.22) : Qt.rgba(0.35, 0.45, 0.62, 0.28)
        readonly property color margin: Qt.rgba(Theme.madder.r, Theme.madder.g, Theme.madder.b, 0.45)
        readonly property real gap: page.lineGap
        readonly property bool fly: page.flyleaf
        onRuleChanged: requestPaint()
        onGapChanged: requestPaint()
        onFlyChanged: requestPaint()
        onPaint: {
            const g = getContext("2d");
            g.reset();
            if (page.flyleaf) return;
            g.strokeStyle = String(rule);
            g.lineWidth = 1;
            for (let y = page.bodyTop + fm.ascent + 4; y < height - 24; y += gap) {
                g.beginPath(); g.moveTo(14, Math.round(y) + 0.5); g.lineTo(width - 14, Math.round(y) + 0.5); g.stroke();
            }
            const mx = page.leftHand ? width - 56 : 56;
            g.strokeStyle = String(margin);
            g.beginPath(); g.moveTo(mx + 0.5, 0); g.lineTo(mx + 0.5, height); g.stroke();
            g.beginPath(); g.moveTo(mx + 3.5, 0); g.lineTo(mx + 3.5, height); g.stroke();
        }
    }

    // the binding: the paper curves down into the gutter
    Rectangle {
        width: 46
        height: parent.height
        x: page.leftHand ? parent.width - width : 0
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: page.leftHand ? "transparent" : Qt.rgba(0, 0, 0, 0.22) }
            GradientStop { position: 1; color: page.leftHand ? Qt.rgba(0, 0, 0, 0.22) : "transparent" }
        }
    }

    // ---------------------------------------------------------------- the flyleaf
    Item {
        anchors.fill: parent
        visible: page.flyleaf
        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 150
            width: 220; height: 220
            source: Qt.resolvedUrl("../../assets/sprig-wash.png")
            sourceSize: Qt.size(440, 440)
            fillMode: Image.PreserveAspectFit
            opacity: 0.7
        }
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 56
            spacing: 6
            InkText { anchors.horizontalCenter: parent.horizontalCenter; text: "Field Notes"; caps: true; tracking: 0.22; font.pixelSize: 22; color: Theme.graphite }
            InkText { anchors.horizontalCenter: parent.horizontalCenter; text: Settings.archiveName; caps: true; tracking: 0.12; font.pixelSize: 11; color: Theme.faded }
        }
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 410
            spacing: 10
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Settings.user
                font.family: Theme.script
                font.pixelSize: 34
                color: Theme.soft
            }
            Rule { anchors.horizontalCenter: parent.horizontalCenter; width: 220; height: implicitHeight; weight: 1; seed: 3101 }
            InkText { anchors.horizontalCenter: parent.horizontalCenter; text: "If found, please return to the herbarium."; font.pixelSize: 12; color: Theme.faded }
        }
    }

    // ---------------------------------------------------------------- the entry
    Item {
        anchors.fill: parent
        visible: !page.flyleaf

        InkText {
            x: page.leftHand ? 24 : 72
            y: 26
            text: page.date !== "" ? page.date : page.today()
            font.pixelSize: 15
            color: Theme.soft
        }
        InkText {
            anchors.right: parent.right
            anchors.rightMargin: page.leftHand ? 72 : 24
            y: 26
            text: "No. " + String(page.number).padStart(3, "0")
            font.pixelSize: 15
            color: Theme.soft
        }
        Row {
            x: page.leftHand ? 24 : 72
            y: 54
            spacing: 8
            InkText { text: "Locality"; font.pixelSize: 13; font.italic: true; color: Theme.labelInk }
            InkText { text: page.locality !== "" ? page.locality : Settings.placeName; font.pixelSize: 13; color: Theme.soft }
        }
        Rule {
            x: page.leftHand ? 14 : 62
            y: 86
            width: parent.width - 76
            height: implicitHeight
            seed: 3200 + page.number
        }

        // read
        Text {
            visible: !page.editable
            x: page.leftHand ? 24 : 72
            y: page.bodyTop
            width: parent.width - 96
            height: parent.height - y - 24
            text: page.body
            font: fm.font
            color: Theme.graphite
            wrapMode: Text.Wrap
            // (no clip: a turning page is drawn in perspective, and a clip
            // there can lose the text altogether)
            maximumLineCount: Math.max(1, Math.floor(height / page.lineGap))
            elide: Text.ElideRight
            renderType: Text.QtRendering
            textFormat: Text.PlainText
        }

        // written
        Flickable {
            id: flick
            visible: page.editable
            x: page.leftHand ? 24 : 72
            y: page.bodyTop
            width: parent.width - 96
            height: parent.height - y - 24
            contentWidth: width
            contentHeight: field.contentHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            function ensureVisible(r) {
                if (contentY >= r.y) contentY = r.y;
                else if (contentY + height <= r.y + r.height) contentY = r.y + r.height - height;
            }
            TextEdit {
                id: field
                width: flick.width
                font: fm.font
                color: Theme.graphite
                wrapMode: TextEdit.Wrap
                selectByMouse: true
                selectionColor: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.3)
                selectedTextColor: Theme.graphite
                textFormat: TextEdit.PlainText
                renderType: Text.QtRendering
                cursorDelegate: Rectangle {
                    width: 2
                    color: Theme.graphite
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: field.activeFocus
                        NumberAnimation { to: 1; duration: 0 }
                        PauseAnimation { duration: 530 }
                        NumberAnimation { to: 0; duration: 0 }
                        PauseAnimation { duration: 530 }
                    }
                }
                onCursorRectangleChanged: flick.ensureVisible(cursorRectangle)
                Keys.onPressed: e => page.keyPressed(e)
                onTextChanged: {
                    if (!page.editable || text === page.body) return;
                    page.body = text;
                    page.edited();
                    saver.restart();
                }
            }
        }
        // a blank page says so, faintly
        InkText {
            visible: page.editable && page.blank && !field.activeFocus
            x: page.leftHand ? 24 : 72
            y: page.bodyTop
            text: "Observations…"
            font: fm.font
            color: Theme.faded
            opacity: 0.6
        }
    }

    function focusField(): void { if (editable) field.forceActiveFocus(); }
    property alias fieldItem: field
}
