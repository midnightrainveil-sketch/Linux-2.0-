import QtQuick
import qs.components

// Notifications: not built yet; its mock-up stands in (art/Notification.png).
// Build it here (this file is widgets/<id>/Main.qml): replace the placeholder with its parts.
Widget {
    id: self
    widgetId: "pager"
    preferredWidth: 1500
    preferredHeight: 600

    WidgetPlaceholder {
        anchors.fill: parent
        widget: self
        name: "Notifications"
        picture: self.art("preview.jpg")
    }
}
