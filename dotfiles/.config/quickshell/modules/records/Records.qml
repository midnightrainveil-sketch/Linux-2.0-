import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.services

// The right record column: stacked Time, Meteorological and Audio cards.
// It lies on the sheet (bottom layer), so working windows cover it, and it
// takes no space from them. On the G14's 16:10 panel the extra height goes
// into breathing room between the cards, never into a fourth card.
PanelWindow {
    id: win

    required property var modelData
    screen: modelData

    readonly property int pad: 24
    anchors { top: true; right: true; bottom: true }
    margins.right: Theme.margin - pad
    margins.bottom: Theme.barHeight
    implicitWidth: Theme.recordWidth + 2 * pad
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "archive-records"
    color: "transparent"
    mask: Region { item: column }

    readonly property real cardsHeight: time.height + weather.height + audio.height
    readonly property int count: (time.visible ? 1 : 0) + (weather.visible ? 1 : 0) + (audio.visible ? 1 : 0)
    // the reference is 1080 px tall; extra height (the G14 is 16:10) becomes
    // a little more air between the cards, never another card
    readonly property real extra: Math.max(0, height - 1080 + Theme.barHeight)

    Column {
        id: column
        x: win.pad
        y: Theme.recordTop + win.extra * 0.15
        width: Theme.recordWidth
        spacing: Theme.cardGap + win.extra * 0.2

        TimeRecord { id: time; width: parent.width; visible: Settings.showTime }
        WeatherRecord { id: weather; width: parent.width; visible: Settings.showWeather }
        AudioRecord { id: audio; width: parent.width; visible: Settings.showAudio }
    }
}
