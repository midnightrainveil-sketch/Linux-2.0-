import QtQuick
import qs.theme

// The aged edge of a card, over its content (it reaches only into the
// card's margin): a blotchy darkening fading inward, and small tears, as on
// the windows' torn edge. Laid over a Paper by IndexCard.
Item {
    anchors.margins: -Theme.frameShadow
    CardFrame { anchors.fill: parent; part: "over"; mode: "day"; opacity: 1 - Theme.night; visible: Theme.night < 0.999 }
    CardFrame { anchors.fill: parent; part: "over"; mode: "night"; opacity: Theme.night; visible: Theme.night > 0.001 }
}
