import QtQuick
import qs.components

// Organizer: not built yet; its mock-up stands in (art/Calendar.png).
// Build it here (this file is widgets/<id>/Main.qml): replace the placeholder with its parts.
Widget {
    id: self
    widgetId: "organizer"
    preferredWidth: 520
    preferredHeight: 780

    WidgetPlaceholder {
        anchors.fill: parent
        widget: self
        name: "Organizer"
        picture: self.art("preview.jpg")
    }
}
