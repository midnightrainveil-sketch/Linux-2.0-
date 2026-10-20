import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.services
import qs.components

// The record cards: Time, Meteorological and Audio, stacked down the right
// of the sheet at login. They lie on the sheet (bottom layer), so working
// windows cover them, and take no space from them. Each can be dragged
// anywhere on the sheet or filed away with a right click; the bar's desk
// button (archive-desk, Super+D) lays them all back. On the G14's 16:10
// panel the extra height goes into breathing room between the cards.
PanelWindow {
    id: win

    required property var modelData
    screen: modelData

    // the whole sheet above the bar, so cards can be dragged anywhere; input
    // reaches the cards only, everything else passes through
    anchors { top: true; left: true; right: true; bottom: true }
    margins.bottom: Theme.barHeight
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "archive-records"
    color: "transparent"
    mask: Region {
        regions: [
            Region { item: time.visible ? time : null },
            Region { item: weather.visible ? weather : null },
            Region { item: audio.visible ? audio : null }
        ]
    }

    // the reference is 1080 px tall; extra height (the G14 is 16:10) becomes
    // a little more air between the cards, never another card
    readonly property real extra: Math.max(0, height - 1080 + Theme.barHeight)
    readonly property real column: width - Theme.margin - Theme.recordWidth
    readonly property real gap: Theme.cardGap + extra * 0.2

    // over the cards the lamp keeps following
    HoverHandler {
        onPointChanged: if (hovered && Lamp.isOn && Theme.night > 0.5) Lamp.moveTo(win.modelData?.name ?? "", point.position.x, point.position.y)
    }

    DeskCard {
        id: time
        name: "time"
        wanted: Settings.showTime
        width: Theme.recordWidth
        homeX: win.column
        homeY: Theme.recordTop + win.extra * 0.15
        TimeRecord { width: parent.width }
    }
    DeskCard {
        id: weather
        name: "weather"
        wanted: Settings.showWeather
        width: Theme.recordWidth
        homeX: win.column
        homeY: Settings.showTime ? time.homeY + time.height + win.gap : time.homeY
        WeatherRecord { width: parent.width }
    }
    DeskCard {
        id: audio
        name: "audio"
        wanted: Settings.showAudio
        width: Theme.recordWidth
        homeX: win.column
        homeY: Settings.showWeather ? weather.homeY + weather.height + win.gap : weather.homeY
        AudioRecord { width: parent.width }
    }

    // the desk lamp's light, over the sheet and the cards alike (night only)
    LampLight {
        anchors.fill: parent
        z: 100
        screenName: win.modelData?.name ?? ""
    }
}
