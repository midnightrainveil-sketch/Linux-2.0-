pragma Singleton

import QtQuick
import Quickshell
import qs.services

// Every design token from the spec (sections 2, 3, 5, 11 and 14) lives here.
// Colours are interpolated between the day and night (cyanotype) sets by
// `night`, which animates over 2 s whenever Mode flips.
Singleton {
    id: root

    // ---------------------------------------------------------------- mode
    property real night: Mode.isNight ? 1 : 0
    Behavior on night {
        NumberAnimation { duration: root.reducedMotion ? 100 : 2000; easing.type: Easing.InOutQuad }
    }

    readonly property bool reducedMotion: Settings.reducedMotion

    function mix(a: color, b: color): color {
        const t = root.night;
        return Qt.rgba(a.r + (b.r - a.r) * t,
                       a.g + (b.g - a.g) * t,
                       a.b + (b.b - a.b) * t,
                       a.a + (b.a - a.a) * t);
    }

    // ---------------------------------------------------------------- day
    readonly property QtObject day: QtObject {
        readonly property color paperBase:   "#C9C7C3"
        readonly property color paperCard:   "#D5D0CA"
        readonly property color paperRaised: "#DDD9D3"
        readonly property color graphite:    "#1E1D22"
        readonly property color soft:        "#3E3D42"
        readonly property color faded:       "#6E6C6D"
        readonly property color ruleInk:     "#4A4950"
        readonly property color ruleFaint:   "#9C9995"
        readonly property color accent:      "#34405E"
        readonly property color wash:        "#7D8698"
        readonly property color madder:      "#7A4A46"
        readonly property color shadow:      Qt.rgba(0x1E / 255, 0x1D / 255, 0x22 / 255, 0.30)
        readonly property color tape:        Qt.rgba(0xE8 / 255, 0xE4 / 255, 0xDC / 255, 0.55)
        readonly property color labelInk:    "#55535a"
        readonly property color sprigInk:    "#4f5a86"
        readonly property color rimTop:      "#8c8780"
        readonly property color rimBottom:   "#6b6660"
    }

    // ---------------------------------------------------------------- night (cyanotype)
    readonly property QtObject nite: QtObject {
        readonly property color paperBase:   "#1C2F4D"
        readonly property color paperCard:   "#22385A"
        readonly property color paperRaised: "#2A4268"
        readonly property color graphite:    "#E6E1D6"
        readonly property color soft:        "#C9CCD2"
        readonly property color faded:       "#8E9CB3"
        readonly property color ruleInk:     "#B8BFCC"
        readonly property color ruleFaint:   "#4E6283"
        readonly property color accent:      "#A9C4E4"
        readonly property color wash:        "#A9C4E4"
        readonly property color madder:      "#D69A8E"
        readonly property color shadow:      Qt.rgba(0x08 / 255, 0x10 / 255, 0x1E / 255, 0.40)
        readonly property color tape:        Qt.rgba(0xE6 / 255, 0xE1 / 255, 0xD6 / 255, 0.22)
        readonly property color labelInk:    "#aeb6c6"
        readonly property color sprigInk:    "#a9c4e4"
        readonly property color rimTop:      "#0f1c30"
        readonly property color rimBottom:   "#08101e"
    }

    // ---------------------------------------------------------------- live tokens
    readonly property color paperBase:   mix(day.paperBase, nite.paperBase)
    readonly property color paperCard:   mix(day.paperCard, nite.paperCard)
    // the cards' torn edge (tools/card-frames.cpp prints these): room for its
    // shadow around a card, and the frame images' border (shadow + corner)
    readonly property int frameShadow: 20
    readonly property int frameBorder: 44
    readonly property color paperRaised: mix(day.paperRaised, nite.paperRaised)
    readonly property color graphite:    mix(day.graphite, nite.graphite)
    readonly property color soft:        mix(day.soft, nite.soft)
    readonly property color faded:       mix(day.faded, nite.faded)
    readonly property color ruleInk:     mix(day.ruleInk, nite.ruleInk)
    readonly property color ruleFaint:   mix(day.ruleFaint, nite.ruleFaint)
    readonly property color accent:      mix(day.accent, nite.accent)
    readonly property color wash:        mix(day.wash, nite.wash)
    readonly property color madder:      mix(day.madder, nite.madder)
    readonly property color shadow:      mix(day.shadow, nite.shadow)
    readonly property color tape:        mix(day.tape, nite.tape)

    // Paper grain strength (section 4): 6-10 % by day, 8-12 % at night.
    // (The windows' grain is the title-bar plugin's, per window; the shell's
    // own cards always carry theirs.)
    readonly property real grainEase:  1.0
    readonly property real grainDark:  (0.08 + 0.02 * night) * grainEase
    readonly property real grainLight: 0.10 * night * grainEase
    // fibre texture on the cards themselves
    readonly property real cardTexture: (1.0 + 0.2 * night) * grainEase

    // ---------------------------------------------------------------- type
    readonly property string typewriter: "Courier Prime"
    readonly property string mono:       "IBM Plex Mono"
    readonly property string script:     "Pinyon Script"
    readonly property string sans:       "IBM Plex Sans"

    // Sizes are measured off the reference mockup at 1920 px wide (the spec's
    // 11 / 12 / 64 px tokens read about 1.4x smaller than the mockup itself).
    readonly property int sizeClock:  92      // with clockStretch: tall typewriter numerals
    readonly property real clockStretch: 1.2
    readonly property int sizeDisplay: 37     // the temperature
    readonly property int sizeTitle:  16
    readonly property int sizeNumber: 16
    readonly property int sizeData:   16
    readonly property int sizeLabel:  16
    readonly property int sizeSmall:  15      // weather table, times, bar status
    readonly property int sizeBar:    16
    readonly property int sizeScript: 22

    // tracking, as a fraction of the font size (QML letterSpacing is in px)
    readonly property real trackTitle: 0.10
    readonly property real trackClock: 0.0

    // ---------------------------------------------------------------- layout
    readonly property int grid:         8
    readonly property int margin:       30      // record column to the screen edge
    readonly property int recordTop:    65
    readonly property int cardGap:      31
    readonly property int cardPad:      27      // text inset from the card edge
    readonly property int ruleInset:    14      // ruled lines stop short of the card edge
    readonly property int headerHeight: 58      // header band, card top to its rule
    readonly property int headerPadH:   23
    readonly property int rowHeight:    38
    readonly property int barHeight:    60
    readonly property int recordWidth:  485
    readonly property real rule:        1.6

    // the cut edge of a card: a thin darker rim, darkest along the bottom
    readonly property color rimTop:     mix(day.rimTop, nite.rimTop)
    readonly property color rimBottom:  mix(day.rimBottom, nite.rimBottom)
    // table labels: a touch lighter than the values, as typed with less pressure
    readonly property color labelInk:   mix(day.labelInk, nite.labelInk)
    // the sprig on the Time Record: a blue-grey watercolour
    readonly property color sprigInk:   mix(day.sprigInk, nite.sprigInk)

    // ---------------------------------------------------------------- motion (section 11)
    // place = cubic-bezier(0.22, 1, 0.36, 1); lift = cubic-bezier(0.4, 0, 1, 1)
    readonly property var place: [0.22, 1, 0.36, 1, 1, 1]
    readonly property var lift:  [0.4, 0, 1, 1, 1, 1]

    function dur(ms: int): int { return reducedMotion ? 100 : ms; }
    readonly property int durWindowIn:  dur(220)
    readonly property int durWindowOut: dur(140)
    readonly property int durFocus:     dur(160)
    readonly property int durPopup:     dur(180)
    readonly property int durStamp:     dur(90)
    readonly property int durDigit:     dur(120)
    // Distance a popup rises out of the bar. Reduced motion = pure fade.
    readonly property int popupRise:    reducedMotion ? 0 : 8
}
