import QtQuick
import qs.theme

// One frame image of the cards' torn edge (tools/card-frames.cpp), stretched
// to its item: the corners as they are, the sides repeated whole strips at a
// time (so the torn edge keeps its grain at any length).
//   part: "under" | "over"     mode: "day" | "night"
BorderImage {
    property string part: "under"
    property string mode: "day"
    source: Qt.resolvedUrl("../assets/card/" + mode + "-" + part + ".png")
    border { left: Theme.frameBorder; right: Theme.frameBorder; top: Theme.frameBorder; bottom: Theme.frameBorder }
    horizontalTileMode: BorderImage.Round
    verticalTileMode: BorderImage.Round
    smooth: true
    cache: true
}
