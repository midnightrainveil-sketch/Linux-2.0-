pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Now playing: picks the most relevant MPRIS player.
Singleton {
    id: root

    readonly property var players: Mpris.players.values
    readonly property MprisPlayer player: {
        const list = root.players;
        return list.find(p => p.isPlaying) ?? list.find(p => p.canControl) ?? list[0] ?? null;
    }

    readonly property bool active: player !== null && (player.trackTitle ?? "") !== ""
    readonly property string title:  player?.trackTitle ?? ""
    readonly property string artist: player?.trackArtist ?? ""
    readonly property string album:  player?.trackAlbum ?? ""
    readonly property string art:    player?.trackArtUrl ?? ""
    readonly property bool playing:  player?.isPlaying ?? false
    readonly property real position: player?.position ?? 0
    readonly property real length:   player?.length ?? 0
    readonly property real progress: length > 0 ? Math.min(1, position / length) : 0

    // Catalogue number: release year of the current track, when the player says.
    readonly property string year: {
        const md = player?.metadata ?? {};
        const raw = md["xesam:contentCreated"] ?? md["year"] ?? "";
        const m = String(raw).match(/\d{4}/);
        return m ? m[0] : "";
    }

    function time(seconds: real): string {
        if (!isFinite(seconds) || seconds < 0) seconds = 0;
        const m = Math.floor(seconds / 60);
        const s = Math.floor(seconds % 60);
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    // shuffle and repeat, where the player offers them
    readonly property bool shuffle: (player?.shuffleSupported ?? false) && (player?.shuffle ?? false)
    readonly property bool looping: (player?.loopSupported ?? false) && (player?.loopState ?? 0) !== 0
    function toggleShuffle(): void {
        try { if (player?.shuffleSupported) player.shuffle = !player.shuffle; } catch (e) {}
    }
    function toggleLoop(): void {
        try { if (player?.loopSupported) player.loopState = player.loopState === 0 ? 2 : 0; } catch (e) {}
    }

    function toggle(): void { if (player?.canTogglePlaying) player.togglePlaying(); }
    function next(): void { if (player?.canGoNext) player.next(); }
    function previous(): void { if (player?.canGoPrevious) player.previous(); }
    function seekTo(seconds: real): void { if (player?.canSeek) player.position = Math.max(0, Math.min(length, seconds)); }
    function seekBy(seconds: real): void { if (player?.canSeek) player.seek(seconds); }

    // MPRIS does not push position updates: ask once a second while playing
    Timer {
        running: root.playing
        interval: 1000
        repeat: true
        onTriggered: root.player?.positionChanged()
    }
}
