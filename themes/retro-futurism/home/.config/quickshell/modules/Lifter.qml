import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.components

// The launcher's lifter while it works: its lower bracket carrying the
// launched app's cartridge down into the taskbar's port on the launcher's
// own rods, and back up. Drawn here, over the taskbar (which sits over the
// launcher's stage while the launcher is up), at the very place the launcher
// had them (Cartridges: liftOX, liftOY, liftK map its mock-up pixels to the
// screen; drop is how far down, which the launcher animates). The cartridge
// is cut off at the port's mouth, so it goes into it. Takes no clicks.
PanelWindow {
    id: lifter

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "retro-futurism-lifter"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"
    mask: Region {}
    visible: Cartridges.lifting

    readonly property real k: Cartridges.liftK
    function X(x) { return Cartridges.liftOX + (x - 24) * k; }
    function Y(y) { return Cartridges.liftOY + (y - 23 + Cartridges.drop) * k; }
    function Y0(y) { return Cartridges.liftOY + (y - 23) * k; }       // (what does not move)
    readonly property string dir: Quickshell.shellPath("widgets/launcher/")

    // the rods, stretched from well up their length down to the bracket
    Image {
        x: lifter.X(627); y: lifter.Y0(240)
        width: 35 * lifter.k; height: (160 + Cartridges.drop) * lifter.k
        source: lifter.dir + "rod-left.png"; fillMode: Image.Stretch; smooth: true
    }
    Image {
        x: lifter.X(920); y: lifter.Y0(240)
        width: 36 * lifter.k; height: (160 + Cartridges.drop) * lifter.k
        source: lifter.dir + "rod-right.png"; fillMode: Image.Stretch; smooth: true
    }
    // the cartridge (the slot's: middle 791, 304, between the rods; scale 0.68), into the port
    Item {
        visible: Cartridges.flying
        x: 0; y: 0
        width: lifter.width
        height: Cartridges.portClipY > 0 ? Cartridges.portClipY : lifter.height
        clip: true
        Cartridge {
            entry: Cartridges.flyEntry
            scale: Cartridges.slotScale * lifter.k
            transformOrigin: Item.Center
            x: lifter.X(791) - width / 2
            y: lifter.Y(304) - height / 2
        }
    }
    // the bracket, in front of it
    Image {
        x: lifter.X(596); y: lifter.Y(396)
        width: implicitWidth * lifter.k; height: implicitHeight * lifter.k
        source: lifter.dir + "bracket.png"
        smooth: true; mipmap: true
    }
}
