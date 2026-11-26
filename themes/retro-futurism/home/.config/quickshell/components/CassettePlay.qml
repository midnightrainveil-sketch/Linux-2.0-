import QtQuick
import QtQuick.Effects
import qs.services

// A cassette player in a picture, playing: its reels turn and its level
// meter lights to the music (services/Spectrum.qml) while something plays;
// at rest it is the picture's own. The parts are cut from the picture by
// tools/make_cassette.py; everything is placed in the picture's pixels and
// mapped to the screen by the picture's offset and scale (ox, oy, k).
//
//   CassettePlay { which: "home"; ox: ...; oy: ...; k: ...; reels: [[x, y], [x, y]]; ... }
Item {
    id: deck

    property string which: "home"           // its pieces: cassette/<which>-*.png
    property real ox: 0
    property real oy: 0
    property real k: 1
    property var reels: []                  // each reel's centre
    property real reelSize: 50              // its sprite, square
    property rect meter: Qt.rect(0, 0, 0, 0) // the meter's window (its sprite)
    // the bars: how many, the first's left edge, the step between them,
    // each one's width, their foot and their tallest
    property int bars: 6
    property real barX: 0
    property real barStep: 6
    property real barW: 5
    property real barFoot: 0
    property real barMax: 12
    property color lit: "#ffb24a"

    property bool still: false              // not to be seen moving: reels and meter rest
    readonly property bool playing: Media.playing && !still
    readonly property string dir: Settings.art + "/cassette/"

    function sx(x) { return ox + x * k; }
    function sy(y) { return oy + y * k; }

    // ---- the reels: turning, both the same way (the tape runs along their
    // foot from left to right), the fuller one slower
    Repeater {
        model: deck.reels
        Image {
            id: reel
            required property var modelData
            required property int index
            source: deck.dir + deck.which + "-reel-" + "lr"[index] + ".png"
            x: deck.sx(modelData[0]) - width / 2; y: deck.sy(modelData[1]) - height / 2
            width: deck.reelSize * deck.k; height: width
            smooth: true; mipmap: true
            visible: status === Image.Ready
            RotationAnimation on rotation {
                from: 360; to: 0
                duration: reel.index === 0 ? 2300 : 1700
                loops: Animation.Infinite
                // (paused, not stopped, between songs: a restart would jump
                // the reel back to where it began)
                running: deck.visible
                paused: running && !deck.playing
            }
        }
    }

    // ---- the meter: its window emptied, its bars lit to the music
    Item {
        id: meterLayer
        anchors.fill: parent
        opacity: deck.playing ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 400 } }
        Image {
            source: deck.dir + deck.which + "-meter.png"
            x: deck.sx(deck.meter.x); y: deck.sy(deck.meter.y)
            width: deck.meter.width * deck.k; height: deck.meter.height * deck.k
            smooth: true
        }
        Item {
            anchors.fill: parent
            layer.enabled: meterLayer.visible
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "#ff9a3c"
                shadowBlur: 0.8
                shadowOpacity: 0.9
                shadowHorizontalOffset: 0; shadowVerticalOffset: 0
            }
            Repeater {
                model: deck.bars
                Rectangle {
                    required property int index
                    // a band of the six for each bar
                    readonly property real level: Spectrum.levels[Math.round(index * 5 / Math.max(1, deck.bars - 1))] ?? 0
                    readonly property real h: Math.max(1.5, deck.barMax * Math.min(1, 0.12 + 0.95 * level))
                    x: deck.sx(deck.barX + index * deck.barStep)
                    width: deck.barW * deck.k
                    height: h * deck.k
                    y: deck.sy(deck.barFoot) - height
                    Behavior on height { NumberAnimation { duration: 70 } }
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#ffe0a0" }
                        GradientStop { position: 1.0; color: deck.lit }
                    }
                }
            }
        }
    }
}
