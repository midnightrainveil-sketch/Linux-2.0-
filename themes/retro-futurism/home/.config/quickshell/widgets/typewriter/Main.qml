import QtQuick
import qs.components

// Typewriter: not built yet; its mock-up stands in (art/Typewriter.png).
// Build it here (this file is widgets/<id>/Main.qml): replace the placeholder with its parts.
Widget {
    id: self
    widgetId: "typewriter"
    preferredWidth: 1170
    preferredHeight: 780

    WidgetPlaceholder {
        anchors.fill: parent
        widget: self
        name: "Typewriter"
        picture: self.art("preview.jpg")
    }
}
