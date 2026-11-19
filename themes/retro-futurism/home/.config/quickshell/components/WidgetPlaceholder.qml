import QtQuick

// Stands in for a widget not built yet: its mock-up, a tag saying so, and
// the last key or click it was given (to show the keyboard and the mouse
// reach it). Esc goes on to the widget, which closes.
FocusScope {
    id: ph

    required property var widget            // the Widget it stands in
    property string picture: ""
    property string name: ""
    property string heard: "Type, or click on it"

    focus: true

    Image {
        id: pic
        anchors.fill: parent
        source: ph.picture
        fillMode: Image.PreserveAspectFit
        smooth: true; mipmap: true
        asynchronous: true
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: e => ph.heard = "Click  " + Math.round(e.x) + ", " + Math.round(e.y)
            + (e.button === Qt.RightButton ? "  (right)" : "")
        onWheel: e => ph.heard = "Scroll  " + (e.angleDelta.y > 0 ? "up" : "down")
    }
    Keys.onPressed: e => {
        if (e.key === Qt.Key_Escape) { e.accepted = false; return; }
        ph.heard = "Key  " + (e.text !== "" && e.text.trim() !== "" ? "“" + e.text + "”" : "#" + e.key);
        e.accepted = true;
    }

    // the tag
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: 18
        width: tag.implicitWidth + 40; height: 58; radius: 10
        color: "#f2eadb"; border.color: "#b8a98e"; border.width: 1
        opacity: 0.94
        Column {
            id: tag
            anchors.centerIn: parent
            spacing: 4
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: (ph.name !== "" ? ph.name.toUpperCase() : ph.widget.widgetId.toUpperCase()) + "  ·  IN THE WORKS  ·  ESC TO PUT AWAY"
                color: "#35312a"; font.family: "Barlow"; font.weight: Font.Bold
                font.pixelSize: 15; font.letterSpacing: 2
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: ph.heard
                color: "#b2512f"; font.family: "Barlow"; font.weight: Font.DemiBold
                font.pixelSize: 15
            }
        }
    }
}
