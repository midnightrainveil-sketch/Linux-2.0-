import QtQml
QtObject {
    property bool isPlaying: true
    property bool canControl: true
    property bool canTogglePlaying: true
    property bool canGoNext: true
    property bool canGoPrevious: true
    property bool canSeek: true
    property string trackTitle: "Night Crossing"
    property string trackArtist: "Arca Quartet"
    property string trackAlbum: ""
    property string trackArtUrl: ""
    property real position: 156
    property real length: 269
    property var metadata: ({})
    property bool shuffleSupported: true
    property bool shuffle: false
    property bool loopSupported: true
    property int loopState: 0
    function togglePlaying() { isPlaying = !isPlaying; }
    function next() {}
    function previous() {}
    function seek(s) {}
}
