pragma Singleton

import QtQuick
import Quickshell.Services.Mpris

QtObject {
    id: root

    readonly property var players: Mpris.players.values.filter(function(candidate) {
        // playerctld exposes a proxy even when it has no controlled player;
        // treating that proxy as media creates noisy DBus reads and a false
        // "available" state for the spectrum process.
        return !candidate.dbusName || String(candidate.dbusName).indexOf("playerctld") < 0;
    })
    property int selectedPlayerUid: 0
    readonly property var player: {
        const selected = players.find(function(candidate) {
            return candidate.uniqueId === selectedPlayerUid;
        });
        if (selected)
            return selected;
        const playing = players.find(function(candidate) { return candidate.isPlaying; });
        return playing || (players.length > 0 ? players[0] : null);
    }
    readonly property bool available: player !== null
    readonly property int playerCount: players.length
    readonly property bool playing: available && player.isPlaying
    readonly property bool canSeek: available && player.canSeek
    readonly property string title: available && player.trackTitle
        ? player.trackTitle : "Nothing playing"
    readonly property string artist: available && player.trackArtist
        ? player.trackArtist : available ? player.identity : "Nothing playing"
    readonly property string album: available && player.trackAlbum
        ? player.trackAlbum : "Unknown album"
    readonly property string artUrl: available ? player.trackArtUrl : ""
    readonly property string identity: available && player.identity ? player.identity : "MPRIS"
    readonly property string sourceUrl: available && player.metadata
        && player.metadata["xesam:url"] ? String(player.metadata["xesam:url"]) : ""
    readonly property real position: available && player.positionSupported ? player.position : 0
    readonly property real length: available && player.lengthSupported ? player.length : 0
    readonly property real progress: length > 0 ? Math.max(0, Math.min(1, position / length)) : 0
    readonly property string mediaKind: {
        const source = (identity + " " + title + " " + sourceUrl).toLowerCase();
        return /mpv|vlc|celluloid|haruna|video|youtube|movie|\.(mp4|mkv|webm|mov)(\?|$)/.test(source)
            ? "VIDEO" : "AUDIO";
    }
    readonly property string statusText: playing ? "PLAYING" : "PAUSED"
    readonly property string timeText: formatTime(position) + " / " + formatTime(length)
    readonly property string embeddedLyrics: available && player.metadata
        ? String(player.metadata["xesam:asText"] || player.metadata["xesam:lyrics"] || "") : ""
    readonly property bool shuffleSupported: available && player.shuffleSupported
    readonly property bool shuffled: shuffleSupported && player.shuffle
    readonly property bool loopSupported: available && player.loopSupported
    readonly property int loopState: loopSupported ? player.loopState : MprisLoopState.None
    readonly property string loopLabel: loopState === MprisLoopState.Track ? "ONE"
        : loopState === MprisLoopState.Playlist ? "ALL" : "OFF"
    readonly property bool rateSupported: available && player.maxRate > player.minRate
    readonly property real rate: available ? player.rate : 1
    readonly property bool playerVolumeSupported: available && player.volumeSupported
    readonly property int playerVolumePercent: playerVolumeSupported
        ? Math.round(player.volume * 100) : 0

    function formatTime(seconds) {
        if (!isFinite(seconds) || seconds < 0)
            return "0:00";
        const whole = Math.floor(seconds);
        const hours = Math.floor(whole / 3600);
        const minutes = Math.floor((whole % 3600) / 60);
        const secs = whole % 60;
        if (hours > 0)
            return hours + ":" + minutes.toString().padStart(2, "0") + ":" + secs.toString().padStart(2, "0");
        return minutes + ":" + secs.toString().padStart(2, "0");
    }

    function toggle() {
        if (available && player.canTogglePlaying)
            player.togglePlaying();
    }

    function next() {
        if (available && player.canGoNext)
            player.next();
    }

    function previous() {
        if (available && player.canGoPrevious)
            player.previous();
    }

    function seekTo(progress) {
        if (!available || !canSeek || length <= 0)
            return;
        player.position = Math.max(0, Math.min(length, progress * length));
    }

    function seekRelative(seconds) {
        if (!available || !canSeek)
            return;
        player.position = Math.max(0, Math.min(length, position + seconds));
    }

    function raise() {
        if (available && player.canRaise)
            player.raise();
    }

    function selectPlayer(uniqueId) {
        const selected = players.find(function(candidate) {
            return candidate.uniqueId === uniqueId;
        });
        if (selected)
            selectedPlayerUid = selected.uniqueId;
    }

    function toggleShuffle() {
        if (shuffleSupported)
            player.shuffle = !player.shuffle;
    }

    function cycleLoop() {
        if (!loopSupported)
            return;
        player.loopState = loopState === MprisLoopState.None ? MprisLoopState.Playlist
            : loopState === MprisLoopState.Playlist ? MprisLoopState.Track
                : MprisLoopState.None;
    }

    function setRate(nextRate) {
        if (!rateSupported)
            return;
        player.rate = Math.max(player.minRate, Math.min(player.maxRate, nextRate));
    }

    function setPlayerVolume(percent) {
        if (playerVolumeSupported)
            player.volume = Math.max(0, Math.min(100, percent)) / 100;
    }

    property Timer positionTimer: Timer {
        interval: 1000
        running: root.available && root.playing
        repeat: true
        onTriggered: {
            if (root.player && root.player.positionSupported)
                root.player.positionChanged();
        }
    }
}
