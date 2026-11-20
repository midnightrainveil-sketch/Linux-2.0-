import QtQuick
import QtQuick.Effects
import qs.services

// An app cartridge (art/Cartridges.png): the clear case and its label, and
// on a blank label the app's own icon set in as though printed on it
// (muted a little, a pressed edge, its shadow on the label). Drawn at its
// own 350 x 445: scale it from outside.
//
//   Cartridge { entry: someDesktopEntry; number: 3 }
//   Cartridge { windowClass: "code" }                 // the taskbar's port
Item {
    id: cart

    property var entry: null
    property string windowClass: ""
    property int number: 0                 // the tab's number (0: none)
    property bool lit: false               // its case glints (chosen)

    readonly property var look: windowClass !== "" ? Cartridges.ofClass(windowClass) : Cartridges.of(entry)

    width: 350
    height: 445

    Image {
        anchors.fill: parent
        source: cart.look ? cart.look.art : ""
        smooth: true; mipmap: true
        asynchronous: true
    }

    // the app's own icon, set into a blank label (the plate's middle is
    // about 62-292 x 108-322)
    Item {
        id: printed
        visible: cart.look && cart.look.icon !== ""
        x: 177 - 75; y: 212 - 75
        width: 150; height: 150

        Image {
            id: icon
            anchors.fill: parent
            source: cart.look ? cart.look.icon : ""
            sourceSize: Qt.size(256, 256)
            smooth: true; mipmap: true
            asynchronous: true
            visible: false
        }
        // the icon, a little muted, as printed, its shadow on the label: one pass
        MultiEffect {
            source: icon
            anchors.fill: icon
            saturation: -0.22
            brightness: -0.04
            shadowEnabled: true
            shadowColor: "#140f0a"
            shadowOpacity: 0.42
            shadowBlur: 0.5
            blurMax: 12
            shadowHorizontalOffset: 2
            shadowVerticalOffset: 4
        }
    }

    // the number on its tab
    Text {
        visible: cart.number > 0
        x: 277 - width / 2; y: 88 - height / 2
        text: (cart.number < 10 ? "0" : "") + cart.number
        color: "#464038"
        font.family: "Barlow"; font.weight: Font.Bold; font.pixelSize: 26
    }

    // chosen: a glint along its clear case
    Rectangle {
        anchors.fill: parent; anchors.margins: 6
        radius: 40
        color: "transparent"
        border.width: 3; border.color: "#fff2d8"
        opacity: cart.lit ? 0.35 : 0
        Behavior on opacity { NumberAnimation { duration: 160 } }
    }
}
