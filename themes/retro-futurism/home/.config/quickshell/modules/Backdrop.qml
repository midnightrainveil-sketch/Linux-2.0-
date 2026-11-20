import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.services
import qs.components

// What lies behind the windows: the picture, the retro-futurism's marks, the
// right-hand column (now playing, notes), and for each window in view a
// caption under it, with focus marks round the one in use.
PanelWindow {
    id: win

    required property var modelData
    screen: modelData

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "retro-futurism-backdrop"
    color: "#0b0a0b"

    // ---- the picture: the girl on the evening train. The city outside her
    // window goes by: a long sunset (window-view.jpg, made to loop) slides
    // behind the glass, and the window, she and the lights reflected in the
    // glass lie over it (wallpaper-front.png, the glass cut out), on the
    // rest of the car (wallpaper.jpg). A picture
    // of your own (settings.json "wallpaper") is shown still, as it is.
    readonly property bool ownPicture: Settings.wallpaper !== ""
    Image {
        anchors.fill: parent
        visible: win.ownPicture
        source: win.ownPicture ? Settings.wallpaper : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        cache: false
    }
    // ---- the ride: the car sways a little, always, and now and then runs
    // over a rail joint. Seconds of the ride so far, counted only while it
    // can be seen.
    QtObject {
        id: ride
        property real t: 0
        property real bumpAt: -100          // when the car last met a joint
        readonly property bool on: !win.ownPicture && !scene.hidden

        // the sway: slow waves of different lengths, so it never falls
        // into a beat (screen pixels; degrees)
        readonly property real swayX: !Settings.sway ? 0
            : 13.0 * Math.sin(t * 0.58) + 5.0 * Math.sin(t * 1.33 + 1.3)
        readonly property real swayY: !Settings.sway ? 0
            : 8.5 * Math.sin(t * 0.81 + 0.4) + 3.5 * Math.sin(t * 1.93 + 2.1)
        readonly property real swayR: !Settings.sway ? 0 : 0.7 * Math.sin(t * 0.47 + 0.8)

        // a joint: each axle gives a short jolt that dies away in a moment;
        // two axles on the front bogie, then two on the back one
        function jolt(s) {
            if (s < 0 || s > 0.6) return 0;
            return Math.exp(-s / 0.11) * Math.sin(2 * Math.PI * 9 * s);
        }
        readonly property real bump: {
            const s = t - bumpAt;
            if (s > 2) return 0;
            return 4.0 * jolt(s) + 3.2 * jolt(s - 0.15) + 3.5 * jolt(s - 0.84) + 2.7 * jolt(s - 0.99);
        }
    }
    FrameAnimation {
        running: ride.on
        onTriggered: ride.t += Math.min(frameTime, 0.1)
    }
    Timer {
        // the next joint: somewhere between 18 and 45 seconds on
        running: ride.on && Settings.bumps
        repeat: true
        interval: 30000
        onTriggered: {
            ride.bumpAt = ride.t;
            interval = 18000 + Math.random() * 27000;
        }
    }

    Item {
        id: scene
        anchors.fill: parent
        visible: !win.ownPicture

        // nothing of it to see: a fullscreen window, or one over the whole glass
        readonly property bool hidden: Hypr.fullscreen
            || Hypr.windows.some(w => w.x <= glass.x && w.y <= glass.y
                                   && w.x + w.w >= glass.x + glass.width
                                   && w.y + w.h >= glass.y + glass.height)

        // We ride in the car: it holds still round us (we sway with it), and
        // only a rail joint jolts it, a touch. What moves is the world
        // outside its window, below. (A touch larger than the screen, so the
        // jolt shows no edge.)
        scale: 1.02
        transform: Translate { x: ride.bump * 0.12; y: ride.bump * 0.45 }

        // the picture's own pixels (3840 x 2160) to the screen, as
        // PreserveAspectCrop lays it
        readonly property real iw: 3840
        readonly property real ih: 2160
        readonly property real k: Math.max(width / iw, height / ih)
        readonly property real ox: (width - iw * k) / 2
        readonly property real oy: (height - ih * k) / 2

        // the whole picture (its glass is covered: by the view, then the front)
        Image {
            x: scene.ox; y: scene.oy
            width: scene.iw * scene.k; height: scene.ih * scene.k
            source: Settings.art + "/wallpaper.jpg"
            fillMode: Image.Stretch
            asynchronous: true
            smooth: true
            cache: false
        }

        // her cassette player, playing while music plays: the reels turn,
        // the meter lights (tools/make_cassette.py)
        CassettePlay {
            anchors.fill: parent
            which: "home"
            ox: scene.ox; oy: scene.oy; k: scene.k
            reels: [[2404, 1517.5], [2501.5, 1523]]
            reelSize: 50
            meter: Qt.rect(2596, 1468, 80, 54)
            bars: 5; barX: 2608.5; barStep: 10.9; barW: 8; barFoot: 1510.5; barMax: 24
        }

        // the glass: 1566,76 to 2982,922 in the picture (its edge is in
        // wallpaper-front.png; this only has to reach under it)
        Item {
            id: glass
            x: scene.ox + 1566 * scene.k; y: scene.oy + 76 * scene.k
            width: 1416 * scene.k; height: 846 * scene.k
            clip: true

            // the view, two copies end to end, sliding left as the train goes
            // (the loop is 1580 x 743; shown at 1.5016 of the picture's scale,
            // its viaduct (row 516) level with the old one, at y 738 of the
            // picture: its top at -36, a good way above the glass and below)
            readonly property real loopW: 1580 * 1.5016 * scene.k
            readonly property real loopH: 743 * 1.5016 * scene.k
            Item {
                // the world outside, as seen from the swaying car: it bobs
                // and drifts past the window frame and rolls a little as the
                // car leans on its springs; a rail joint jumps it more than
                // the car (the springs pass the jolt on, the eye is jolted)
                x: 0.7 * ride.swayX + ride.bump * 0.3
                y: ride.swayY + ride.bump * 1.3
                width: glass.width; height: glass.height
                transform: Rotation { origin.x: glass.width / 2; origin.y: glass.height / 2; angle: 0.8 * ride.swayR }
                Row {
                    id: view
                    y: (-36.4 - 76) * scene.k
                    // how far round the city has come, 0..1 (the animation runs on
                    // this, not on x: x then follows the screen's size, whatever it
                    // is when the animation starts)
                    property real progress: 0
                    // (made again, it goes on from where the city had got to)
                    property real startAt: 0
                    property bool ready: false
                    Component.onCompleted: { startAt = Scene.viewShift; ready = true; }
                    // (a little to the left as well: the sway never opens a gap at the glass's edge)
                    x: -(progress % 1) * glass.loopW - 32
                    // where the city has got to (the lock screen fades into it)
                    onProgressChanged: Scene.viewShift = progress % 1
                    Repeater {
                        model: 2
                        Image {
                            width: glass.loopW; height: glass.loopH
                            source: Settings.art + "/window-view.jpg"
                            fillMode: Image.Stretch
                            asynchronous: true
                            smooth: true
                        }
                    }
                    NumberAnimation on progress {
                        from: view.startAt; to: view.startAt + 1
                        duration: Math.max(1, Settings.windowSeconds) * 1000
                        loops: Animation.Infinite
                        running: !win.ownPicture && view.ready
                        paused: running && (Settings.windowSeconds <= 0 || scene.hidden)
                    }
                }
            }
            // the glass itself: a faint cool cast over what lies outside
            Rectangle { anchors.fill: parent; color: "#465578"; opacity: 0.10 }
        }

        // the window over it: she, the frame, the lights reflected in the
        // glass (1540,60 to 3010,950 of the picture, the glass see-through)
        Image {
            x: scene.ox + 1540 * scene.k; y: scene.oy + 60 * scene.k
            width: 1470 * scene.k; height: 890 * scene.k
            source: Settings.art + "/wallpaper-front.png"
            fillMode: Image.Stretch
            asynchronous: true
            smooth: true
            cache: false
        }
    }

    // ---- dimmed while windows are open on the workspace in view: the
    // picture steps back behind them, and comes up again on an empty one
    // (a picture of your own too). Hyprland's chromerim plugin does it
    // itself when it is loaded, following the slides and swipes frame by
    // frame (hypr/theme/look.lua: desk_dim); this is for when it is not.
    Rectangle {
        anchors.fill: parent
        color: "#0d0907"
        opacity: !Hypr.rimDrawn && Hypr.windows.length > 0 ? 0.5 : 0
        visible: opacity > 0.001
        Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
    }

    // ---- the window frames, where Hyprland does not draw them: its
    // chromerim plugin draws the taskbar's rim round each window itself, in
    // step with it (hypr/theme/look.lua). Only until that is built, and round
    // X11 windows it leaves out, the same rim is drawn here
    // (components/Frame.qml), touching the window: bright on the one in use,
    // a shade darker on the others. They follow the windows as Hyprland
    // reports them (services/Hypr.qml), and step aside for a fullscreen one.
    Item {
        id: frames
        anchors.fill: parent
        visible: !Hypr.fullscreen
        Repeater {
            model: Hypr.rimDrawn ? Hypr.windows.filter(w => w.x11) : Hypr.windows
            Item {
                id: framed
                required property var modelData
                readonly property real out: Theme.frameRim + Theme.frameGap      // window edge to the frame's outer edge (the rim's inner edge a pixel under the window)
                x: modelData.x - out; y: modelData.y - out
                width: modelData.w + 2 * out; height: modelData.h + 2 * out
                Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1] } }
                Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1] } }
                Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1] } }
                Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1] } }

                // the frame: a drawn chrome border (components/Frame.qml)
                Frame {
                    anchors.fill: parent
                    rim: Theme.frameRim
                    innerR: Theme.windowRounding
                    dim: !framed.modelData.active
                }
            }
        }
    }
}
