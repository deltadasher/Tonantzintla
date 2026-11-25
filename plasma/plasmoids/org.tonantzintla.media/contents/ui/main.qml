pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.private.mpris as Mpris

PlasmoidItem {
    id: root
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    readonly property var player: mprisModel.currentPlayer
    readonly property bool hasPlayer: player !== null && player !== undefined
    readonly property bool playing: hasPlayer && player.playbackStatus === 2
    readonly property color accentColor: Kirigami.Theme.focusColor
    function linChannel(c) { return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4); }
    readonly property color accentFg: (0.2126 * linChannel(accentColor.r) + 0.7152 * linChannel(accentColor.g) + 0.0722 * linChannel(accentColor.b)) > 0.34 ? "#101016" : "#f8f7fc"
    // JetBrains Mono when it is installed; otherwise the system fixed-width font, so digits never shift.
    readonly property string monoFamily: Qt.fontFamilies().indexOf("JetBrains Mono") >= 0
        ? "JetBrains Mono"
        : Kirigami.Theme.fixedWidthFont.family

    property real progressRatio: 0.0
    property real trackLengthUs: 0.0
    property string posLabel: "00:00"
    property string lenLabel: "--:--"
    property bool isSeeking: false

    readonly property int trackSeed: {
        const s = hasPlayer ? String(player.track || player.identity || "tonantzintla") : "tonantzintla";
        let h = 2166136261;
        for (let i = 0; i < s.length; i++) {
            h ^= s.charCodeAt(i);
            h = (h * 16777619) >>> 0;
        }
        return h;
    }

    function fmtUs(us) {
        const secs = Math.max(0, Math.floor((Number(us) || 0) / 1000000));
        const m = Math.floor(secs / 60);
        const s = secs % 60;
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    // The player picks this URL, and a web page can be the player. Only ordinary image locations are loaded.
    function safeArtUrl(url) {
        const value = String(url || "");
        return (/^(file|https?):\/\//i.test(value) || /^data:image\//i.test(value)) ? value : "";
    }

    Mpris.Mpris2Model {
        id: mprisModel
    }

    Timer {
        interval: 1000
        running: root.expanded && root.hasPlayer
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!root.hasPlayer || root.isSeeking) return;
            root.player.updatePosition();
            const len = Number(root.player.length) || 0;
            const pos = Number(root.player.position) || 0;
            root.trackLengthUs = len;
            root.progressRatio = len > 0 ? Math.max(0, Math.min(1, pos / len)) : 0;
            root.posLabel = root.fmtUs(pos);
            root.lenLabel = len > 0 ? root.fmtUs(len) : "--:--";
        }
    }

    compactRepresentation: Item {
        Layout.minimumWidth: root.hasPlayer ? pill.implicitWidth : 0
        Layout.preferredWidth: root.hasPlayer ? pill.implicitWidth : 0
        Layout.maximumWidth: root.hasPlayer ? 290 : 0
        Layout.fillHeight: true

        Rectangle {
            id: pill
            visible: root.hasPlayer
            anchors.centerIn: parent
            implicitWidth: Math.min(284, contentRow.implicitWidth + 14)
            implicitHeight: 28
            radius: 8
            color: mediaHover.hovered || root.expanded ? Kirigami.Theme.alternateBackgroundColor : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }
            HoverHandler { id: mediaHover }

            RowLayout {
                id: contentRow
                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                spacing: 7

                // Truly circular rotating vinyl disc emblem (anti-aliased Canvas circular clip, GPU rotated)
                Item {
                    id: miniVinyl
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22

                    Image {
                        id: miniArtSrc
                        source: root.hasPlayer ? root.safeArtUrl(root.player.artUrl) : ""
                        visible: false
                        asynchronous: true
                        onStatusChanged: miniVinylCanvas.requestPaint()
                        onSourceChanged: miniVinylCanvas.requestPaint()
                    }

                    Canvas {
                        id: miniVinylCanvas
                        anchors.fill: parent
                        antialiasing: true

                        RotationAnimator on rotation {
                            from: 0; to: 360; duration: 6000
                            loops: Animation.Infinite
                            running: root.hasPlayer
                            paused: running && !root.playing
                        }

                        Connections {
                            target: root
                            function onPlayingChanged() { miniVinylCanvas.requestPaint(); }
                            function onAccentColorChanged() { miniVinylCanvas.requestPaint(); }
                        }

                        onPaint: {
                            const ctx = getContext("2d");
                            const w = width, h = height;
                            const cx = w * 0.5, cy = h * 0.5, r = w * 0.5 - 0.5;
                            ctx.clearRect(0, 0, w, h);

                            ctx.save();
                            ctx.beginPath();
                            ctx.arc(cx, cy, r, 0, Math.PI * 2);
                            ctx.clip();

                            ctx.fillStyle = "#0b0b11";
                            ctx.fillRect(0, 0, w, h);

                            if (miniArtSrc.status === Image.Ready && miniArtSrc.implicitWidth > 0) {
                                const iw = miniArtSrc.implicitWidth, ih = miniArtSrc.implicitHeight;
                                const sc = Math.max(w / iw, h / ih);
                                const dw = iw * sc, dh = ih * sc;
                                ctx.drawImage(miniArtSrc, (w - dw) * 0.5, (h - dh) * 0.5, dw, dh);
                            }

                            ctx.strokeStyle = "rgba(255,255,255,0.16)";
                            ctx.lineWidth = 0.7;
                            ctx.beginPath(); ctx.arc(cx, cy, r - 2.6, 0, Math.PI * 2); ctx.stroke();

                            ctx.fillStyle = "#0b0b11";
                            ctx.beginPath(); ctx.arc(cx, cy, 3.0, 0, Math.PI * 2); ctx.fill();
                            ctx.strokeStyle = root.accentColor;
                            ctx.lineWidth = 1.0;
                            ctx.beginPath(); ctx.arc(cx, cy, 3.0, 0, Math.PI * 2); ctx.stroke();
                            ctx.restore();

                            ctx.strokeStyle = root.playing
                                ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.75)
                                : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.22);
                            ctx.lineWidth = 1.0;
                            ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.stroke();
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: miniArtSrc.status !== Image.Ready
                        text: "♪"
                        color: root.accentColor
                        font.pixelSize: 10
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.expanded = !root.expanded
                    }
                }

                // Live 3-bar acoustic micro-visualizer
                Row {
                    visible: root.playing
                    spacing: 1.5
                    Layout.alignment: Qt.AlignVCenter
                    Repeater {
                        model: 3
                        Item {
                            id: eqSlot
                            required property int index
                            width: 2
                            height: 12
                            Rectangle {
                                width: 2; height: 4; radius: 1
                                anchors.bottom: parent.bottom
                                color: root.accentColor
                                SequentialAnimation on height {
                                    running: root.playing
                                    loops: Animation.Infinite
                                    NumberAnimation { to: eqSlot.index === 1 ? 11 : (eqSlot.index === 0 ? 9 : 8); duration: 240 + eqSlot.index * 95; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 3; duration: 220 + eqSlot.index * 80; easing.type: Easing.InOutSine }
                                }
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.maximumWidth: 148
                    text: root.hasPlayer ? (root.player.track || root.player.identity || "Media") : ""
                    color: root.playing ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
                    font.family: root.monoFamily
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.expanded = !root.expanded
                    }
                }

                Kirigami.Icon {
                    Layout.preferredWidth: 14
                    Layout.preferredHeight: 14
                    source: "media-skip-backward"
                    isMask: true
                    color: prevMouse.containsMouse ? root.accentColor : Kirigami.Theme.disabledTextColor
                    MouseArea {
                        id: prevMouse
                        anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.hasPlayer) root.player.Previous()
                    }
                }
                Rectangle {
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22
                    radius: 6
                    color: playMouse.containsMouse ? root.accentColor : Kirigami.Theme.alternateBackgroundColor
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: 12; height: 12
                        source: root.playing ? "media-playback-pause" : "media-playback-start"
                        isMask: true
                        color: playMouse.containsMouse ? root.accentFg : Kirigami.Theme.textColor
                    }
                    MouseArea {
                        id: playMouse
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.hasPlayer) root.player.PlayPause()
                    }
                }
                Kirigami.Icon {
                    Layout.preferredWidth: 14
                    Layout.preferredHeight: 14
                    source: "media-skip-forward"
                    isMask: true
                    color: nextMouse.containsMouse ? root.accentColor : Kirigami.Theme.disabledTextColor
                    MouseArea {
                        id: nextMouse
                        anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.hasPlayer) root.player.Next()
                    }
                }
            }
        }
    }

    // ULTRA-CLEAN GLSL ANISOTROPIC VINYL & LIVING HARMONIC WAVEFORM DECK
    fullRepresentation: Item {
        id: deckRoot
        implicitWidth: 344
        implicitHeight: 214

        property real hoverRatio: -1.0
        readonly property bool hoveringWave: hoverRatio >= 0.0
        property real vinylAngle: 0.45
        property real waveTime: 0.0
        property real playBlend: root.playing ? 1.0 : 0.0
        Behavior on playBlend { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

        FrameAnimation {
            running: deckRoot.visible && root.hasPlayer
            onTriggered: {
                const dt = Math.min(0.05, Math.max(0.001, frameTime));
                deckRoot.waveTime = (deckRoot.waveTime + dt) % 1000.0;
                if (deckRoot.playBlend > 0.005) {
                    deckRoot.vinylAngle = (deckRoot.vinylAngle + dt * 1.25 * deckRoot.playBlend) % 628.3185;
                }
            }
        }

        // Pinned to the top so a resized popup keeps its rhythm instead of spreading the rows apart.
        ColumnLayout {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 16
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                // Peeking GPU anisotropic vinyl record + truly rounded album sleeve
                Item {
                    Layout.preferredWidth: 114
                    Layout.preferredHeight: 76

                    // GLSL anisotropic brushed-vinyl shader with spring slide-out
                    ShaderEffect {
                        id: vinylShader
                        width: 72; height: 72
                        x: root.playing ? 40 : 10
                        y: 2
                        Behavior on x { SpringAnimation { spring: 3.8; damping: 0.42; epsilon: 0.25 } }

                        property real uAngle: deckRoot.vinylAngle
                        property real uPlaying: deckRoot.playBlend
                        property vector2d uResolution: Qt.vector2d(width, height)
                        property color uAccent: root.accentColor
                        fragmentShader: Qt.resolvedUrl("../shaders/vinyl_disc.frag.qsb")
                    }

                    // Soft sleeve shadow cast onto the peeking vinyl
                    Rectangle {
                        z: 1
                        x: 72; y: 4
                        width: 14; height: 68
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.58) }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                    }

                    // True anti-aliased rounded-corner album sleeve (Canvas rounded clip, zero square corners)
                    Item {
                        z: 2
                        width: 76; height: 76

                        Image {
                            id: deckArtSrc
                            source: root.hasPlayer ? root.safeArtUrl(root.player.artUrl) : ""
                            visible: false
                            asynchronous: true
                            onStatusChanged: sleeveCanvas.requestPaint()
                            onSourceChanged: sleeveCanvas.requestPaint()
                        }

                        Canvas {
                            id: sleeveCanvas
                            anchors.fill: parent
                            antialiasing: true
                            onPaint: {
                                const ctx = getContext("2d");
                                const w = width, h = height, r = 11;
                                ctx.clearRect(0, 0, w, h);

                                function roundedPath(pad, rad) {
                                    ctx.beginPath();
                                    ctx.moveTo(pad + rad, pad);
                                    ctx.lineTo(w - pad - rad, pad);
                                    ctx.quadraticCurveTo(w - pad, pad, w - pad, pad + rad);
                                    ctx.lineTo(w - pad, h - pad - rad);
                                    ctx.quadraticCurveTo(w - pad, h - pad, w - pad - rad, h - pad);
                                    ctx.lineTo(pad + rad, h - pad);
                                    ctx.quadraticCurveTo(pad, h - pad, pad, h - pad - rad);
                                    ctx.lineTo(pad, pad + rad);
                                    ctx.quadraticCurveTo(pad, pad, pad + rad, pad);
                                    ctx.closePath();
                                }

                                ctx.save();
                                roundedPath(0, r);
                                ctx.clip();

                                ctx.fillStyle = Kirigami.Theme.alternateBackgroundColor;
                                ctx.fillRect(0, 0, w, h);

                                if (deckArtSrc.status === Image.Ready && deckArtSrc.implicitWidth > 0) {
                                    const iw = deckArtSrc.implicitWidth, ih = deckArtSrc.implicitHeight;
                                    const sc = Math.max(w / iw, h / ih);
                                    const dw = iw * sc, dh = ih * sc;
                                    ctx.drawImage(deckArtSrc, (w - dw) * 0.5, (h - dh) * 0.5, dw, dh);
                                }
                                ctx.restore();

                                roundedPath(0.5, r - 0.5);
                                ctx.strokeStyle = "rgba(255,255,255,0.12)";
                                ctx.lineWidth = 1.0;
                                ctx.stroke();
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: deckArtSrc.status !== Image.Ready
                            text: "♪"
                            color: root.accentColor
                            font.pixelSize: 26
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        Layout.fillWidth: true
                        text: root.hasPlayer ? (root.player.track || "No Track") : "Nothing Playing"
                        color: Kirigami.Theme.textColor
                        font.family: root.monoFamily
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.hasPlayer ? (root.player.artist || root.player.identity || "") : ""
                        color: Kirigami.Theme.disabledTextColor
                        font.family: root.monoFamily
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                }
            }

            // GLSL Living 32-Bar Harmonic Waveform Seekbar with Gaussian Hover Wave & Drag Scrub
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 5

                Item {
                    id: waveTrack
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32

                    ShaderEffect {
                        anchors.fill: parent
                        property real uTime: deckRoot.waveTime
                        property real uProgress: root.progressRatio
                        property real uHoverRatio: deckRoot.hoverRatio
                        property real uPlaying: deckRoot.playBlend
                        property real uSeed: (root.trackSeed % 97)
                        property vector2d uResolution: Qt.vector2d(width, height)
                        property color uAccent: root.accentColor
                        property color uText: Kirigami.Theme.textColor
                        fragmentShader: Qt.resolvedUrl("../shaders/media_wave.frag.qsb")
                    }

                    MouseArea {
                        id: waveMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: (root.hasPlayer && root.player.canSeek && root.trackLengthUs > 0) ? Qt.PointingHandCursor : Qt.ArrowCursor
                        function ratioForX(mx) {
                            return Math.max(0, Math.min(1, mx / Math.max(1, waveTrack.width)));
                        }
                        function commitSeek(ratio) {
                            if (!root.hasPlayer || !root.player.canSeek) return;
                            const len = Number(root.player.length) || 0;
                            if (len <= 0) return;
                            const target = ratio * len;
                            const cur = Number(root.player.position) || 0;
                            root.player.Seek(Math.round(target - cur));
                            root.progressRatio = ratio;
                            root.posLabel = root.fmtUs(target);
                        }
                        onPositionChanged: function(mouse) {
                            const r = ratioForX(mouse.x);
                            deckRoot.hoverRatio = r;
                            if (pressed && root.hasPlayer && root.trackLengthUs > 0) {
                                root.progressRatio = r;
                                root.posLabel = root.fmtUs(r * root.trackLengthUs);
                            }
                        }
                        onExited: if (!pressed) deckRoot.hoverRatio = -1.0
                        onPressed: function(mouse) {
                            if (!root.hasPlayer || !root.player.canSeek || root.trackLengthUs <= 0) return;
                            root.isSeeking = true;
                            const r = ratioForX(mouse.x);
                            deckRoot.hoverRatio = r;
                            root.progressRatio = r;
                            root.posLabel = root.fmtUs(r * root.trackLengthUs);
                        }
                        onReleased: function(mouse) {
                            if (root.isSeeking) {
                                commitSeek(ratioForX(mouse.x));
                                root.isSeeking = false;
                            }
                            if (!containsMouse) deckRoot.hoverRatio = -1.0;
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: (deckRoot.hoveringWave && root.trackLengthUs > 0)
                            ? root.fmtUs(deckRoot.hoverRatio * root.trackLengthUs)
                            : root.posLabel
                        color: deckRoot.hoveringWave && root.trackLengthUs > 0 ? root.accentColor : Kirigami.Theme.disabledTextColor
                        font.family: root.monoFamily
                        font.pixelSize: 10
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: root.lenLabel
                        color: Kirigami.Theme.disabledTextColor
                        font.family: root.monoFamily
                        font.pixelSize: 10
                    }
                }
            }

            // Crisp geometric transport controls with spring press feel
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Item { Layout.fillWidth: true }
                Rectangle {
                    Layout.preferredWidth: 36; Layout.preferredHeight: 34; radius: 9
                    color: deckPrev.containsMouse ? Kirigami.Theme.alternateBackgroundColor : "transparent"
                    scale: deckPrev.pressed ? 0.90 : 1.0
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on scale { SpringAnimation { spring: 6.0; damping: 0.42 } }
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: 16; height: 16
                        source: "media-skip-backward"
                        isMask: true
                        color: deckPrev.containsMouse ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
                    }
                    MouseArea { id: deckPrev; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (root.hasPlayer) root.player.Previous() }
                }
                Rectangle {
                    Layout.preferredWidth: 54; Layout.preferredHeight: 36; radius: 11
                    color: root.accentColor
                    scale: deckPlay.pressed ? 0.92 : (deckPlay.containsMouse ? 1.07 : 1.0)
                    Behavior on scale { SpringAnimation { spring: 5.5; damping: 0.36 } }
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: 17; height: 17
                        source: root.playing ? "media-playback-pause" : "media-playback-start"
                        isMask: true
                        color: root.accentFg
                    }
                    MouseArea { id: deckPlay; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (root.hasPlayer) root.player.PlayPause() }
                }
                Rectangle {
                    Layout.preferredWidth: 36; Layout.preferredHeight: 34; radius: 9
                    color: deckNext.containsMouse ? Kirigami.Theme.alternateBackgroundColor : "transparent"
                    scale: deckNext.pressed ? 0.90 : 1.0
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on scale { SpringAnimation { spring: 6.0; damping: 0.42 } }
                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: 16; height: 16
                        source: "media-skip-forward"
                        isMask: true
                        color: deckNext.containsMouse ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
                    }
                    MouseArea { id: deckNext; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (root.hasPlayer) root.player.Next() }
                }
                Item { Layout.fillWidth: true }
            }
        }
    }
}
