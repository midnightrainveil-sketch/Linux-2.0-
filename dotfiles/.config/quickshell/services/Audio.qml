pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Default output volume. Hyprland's media keys change it with wpctl; this
// notices the change and asks the shell to show the Instrument reading.
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool ready: sink?.ready ?? false
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property int percent: Math.round(volume * 100)

    signal changed()

    function setVolume(v: real): void {
        if (sink?.audio) {
            sink.audio.muted = false;
            sink.audio.volume = Math.max(0, Math.min(1, v));
        }
    }
    function toggleMute(): void { if (sink?.audio) sink.audio.muted = !sink.audio.muted; }

    PwObjectTracker { objects: [root.sink] }

    // Ignore the burst of updates while the sink first binds.
    property bool settled: false
    Timer { running: root.ready; interval: 1500; onTriggered: root.settled = true }
    onSinkChanged: settled = false

    onVolumeChanged: if (settled) { changed(); Sounds.play("volume"); }
    onMutedChanged: if (settled) changed()
}
