import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../shared" as Shared
import "../../../.."
import "../../../../components"
import "../../../../services"

pragma ComponentBehavior: Bound

Item {
    id: root

    property int currentTab: 0
    // The last spectrum the corona showed. Retained while paused so the halo
    // freezes on real audio instead of wobbling on invented data.
    property var haloBands: []
    readonly property real spectrumEnergy: {
        if (!Spectrum.available || Spectrum.values.length === 0)
            return 0;
        let total = 0;
        Spectrum.values.forEach(function(value) { total += Number(value || 0); });
        return total / Spectrum.values.length;
    }
    // Tab panels sit over the ambience, so they tint the light rather than
    // hiding it. Opaque panels would waste the whole effect.
    readonly property color panelTint: Qt.rgba(Theme.mantle.r, Theme.mantle.g,
        Theme.mantle.b, 0.62)
    readonly property var frequencyLabels: ["31", "63", "125", "250", "500", "1K", "2K", "4K", "8K", "16K"]

    function focusPrimary() { tabRow.forceActiveFocus(); }

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Left) {
            Media.seekRelative(-10); event.accepted = true;
        } else if (event.key === Qt.Key_Right) {
            Media.seekRelative(10); event.accepted = true;
        } else if (event.key === Qt.Key_Space) {
            Media.toggle(); event.accepted = true;
        }
    }

    Connections {
        target: Spectrum
        enabled: Media.playing
        function onValuesChanged() { root.haloBands = Spectrum.values.slice(); }
    }

    component TransportButton: Rectangle {
        property string glyph: ""
        property string label: ""
        property bool primary: false
        signal activated
        implicitWidth: primary ? 58 : 46
        implicitHeight: primary ? 58 : 46
        radius: primary ? 19 : 15
        color: primary ? Theme.accent : transportPointer.containsMouse ? Theme.accentVeil : Theme.elevated
        border.width: 0
        border.color: primary ? Theme.accent : transportPointer.containsMouse ? Theme.accentLine : Theme.line
        scale: transportPointer.containsMouse ? 1.07 : 1
        Column {
            anchors.centerIn: parent
            spacing: -2
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: parent.parent.glyph
                color: parent.parent.primary ? Theme.void_ : Theme.moon
                font.family: Theme.fontIcon
                font.pixelSize: parent.parent.primary ? 21 : 17
                font.weight: Font.Bold
            }
            Text {
                visible: parent.parent.label.length > 0
                anchors.horizontalCenter: parent.horizontalCenter
                text: parent.parent.label
                color: parent.parent.primary ? Theme.void_ : Theme.muted
                font.family: Theme.fontMono
                font.pixelSize: 10
                font.weight: Font.Bold
            }
        }
        MouseArea { id: transportPointer; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.activated() }
        Behavior on scale { NumberAnimation { duration: Settings.motion ? Theme.motionFast : 0; easing.type: Easing.OutBack } }
    }

    component ModeButton: Rectangle {
        property string glyph: ""
        property string label: ""
        property bool active: false
        property bool enabledControl: true
        signal activated
        implicitWidth: modeContent.implicitWidth + 20
        implicitHeight: 34
        radius: 11
        color: active ? Theme.accentVeil
            : modePointer.containsMouse ? Theme.elevated : Theme.mantle
        border.width: 0
        border.color: active ? Theme.accentLine : Theme.barHairlineHover
        opacity: enabledControl ? 1 : 0.34
        Row {
            id: modeContent
            anchors.centerIn: parent
            spacing: 6
            Text { text: parent.parent.glyph; color: parent.parent.active ? Theme.accent : Theme.muted; font.family: Theme.fontIcon; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
            Text { text: parent.parent.label; color: parent.parent.active ? Theme.moon : Theme.muted; font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
        }
        MouseArea { id: modePointer; anchors.fill: parent; enabled: parent.enabledControl; hoverEnabled: true; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: parent.activated() }
    }

    component PitchTrack: Item {
        id: pitchTrack
        property string label: ""
        property string suffix: ""
        property real from: 0
        property real to: 100
        property real step: 1
        property real value: 0
        property real liveValue: value
        property color tone: Theme.accent
        property bool controlEnabled: true
        signal committed(real value)
        implicitHeight: 68
        opacity: controlEnabled ? 1 : 0.34

        onValueChanged: if (!trackPointer.pressed) liveValue = value

        Text {
            anchors.left: parent.left; anchors.top: parent.top
            text: pitchTrack.label
            color: Theme.muted; font.family: Theme.fontMono
            font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 1.1
        }
        Text {
            anchors.right: parent.right; anchors.top: parent.top
            text: (pitchTrack.liveValue > 0 ? "+" : "")
                + Math.round(pitchTrack.liveValue) + pitchTrack.suffix
            color: pitchTrack.tone; font.family: Theme.fontDisplay
            font.pixelSize: 15; font.weight: Font.Black
        }
        Rectangle {
            anchors.left: parent.left; anchors.right: parent.right
            anchors.bottom: parent.bottom; height: 30; radius: 15
            color: Theme.elevated
            Rectangle {
                anchors.left: parent.left; anchors.leftMargin: 5
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(10, (parent.width - 10)
                    * (pitchTrack.liveValue - pitchTrack.from)
                    / Math.max(1, pitchTrack.to - pitchTrack.from))
                height: 5; radius: 3; color: pitchTrack.tone; opacity: 0.68
            }
            Rectangle {
                x: 5 + (parent.width - width - 10)
                    * (pitchTrack.liveValue - pitchTrack.from)
                    / Math.max(1, pitchTrack.to - pitchTrack.from)
                anchors.verticalCenter: parent.verticalCenter
                width: trackPointer.pressed ? 22 : 17; height: width; radius: width / 2
                color: pitchTrack.tone
                Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
                Behavior on x {
                    enabled: !trackPointer.pressed
                    NumberAnimation { duration: Settings.motion ? 260 : 0; easing.type: Easing.OutBack }
                }
            }
            MouseArea {
                id: trackPointer
                anchors.fill: parent
                enabled: pitchTrack.controlEnabled
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                function updateValue(px) {
                    const ratio = Math.max(0, Math.min(1, (px - 5) / Math.max(1, width - 10)));
                    const raw = pitchTrack.from + ratio * (pitchTrack.to - pitchTrack.from);
                    pitchTrack.liveValue = Math.round(raw / pitchTrack.step) * pitchTrack.step;
                }
                onPressed: function(mouse) { updateValue(mouse.x); }
                onPositionChanged: function(mouse) { if (pressed) updateValue(mouse.x); }
                onReleased: function(mouse) {
                    updateValue(mouse.x);
                    pitchTrack.committed(pitchTrack.liveValue);
                }
            }
        }
    }

    Shared.ResonanceAmbience {
        anchors.fill: parent
        anchors.margins: -24
        artUrl: Media.artUrl
        intensity: 0.34
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12
        RowLayout {
            Layout.fillWidth: true
            spacing: 14
            Text {
                Layout.fillWidth: true
                text: "MEDIA"
                color: Theme.moon
                font.family: Theme.fontDisplay
                font.pixelSize: 23
                font.weight: Font.Black
            }
            RowLayout {
                id: tabRow
                spacing: 5
                focus: true
                Repeater {
                    model: [
                        { "label": "NOW PLAYING", "code": "MPR" },
                        { "label": "LYRICS", "code": "LRC" },
                        { "label": "PITCHER", "code": "PCH" },
                        { "label": "EQUALIZER", "code": "EQL" }
                    ]
                    Rectangle {
                        id: tabButton
                        required property var modelData
                        required property int index
                        readonly property bool active: root.currentTab === index
                        Layout.preferredWidth: tabButton.index === 0 ? 116 : 94; Layout.preferredHeight: 38
                        radius: 0
                        color: tabPointer.containsMouse
                            ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.06)
                            : "transparent"
                        border.width: 0
                        Text {
                            anchors.centerIn: parent
                            text: tabButton.modelData.label
                            color: tabButton.active ? Theme.moon : Theme.muted
                            font.family: Theme.fontText
                            font.pixelSize: 12
                            font.weight: Font.Bold
                        }
                        Rectangle {
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            width: tabButton.active || tabPointer.containsMouse ? parent.width : 0
                            height: 2
                            color: Theme.accent
                            opacity: tabButton.active || tabPointer.containsMouse ? 1 : 0
                            Behavior on width { NumberAnimation { duration: Settings.motion ? 140 : 0; easing.type: Easing.OutCubic } }
                            Behavior on opacity { NumberAnimation { duration: Settings.motion ? 90 : 0 } }
                        }
                        MouseArea { id: tabPointer; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.currentTab = tabButton.index }
                    }
                }
            }
        }
        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            sourceComponent: root.currentTab === 0 ? nowPlayingPage
                : root.currentTab === 1 ? lyricsPage
                : root.currentTab === 2 ? pitcherPage : equalizerPage
        }
    }

    Component {
        id: nowPlayingPage
        RowLayout {
            spacing: 16
            Item {
                id: resonancePlanet
                Layout.preferredWidth: 400
                Layout.fillHeight: true

                Shared.OrbitSeek {
                    id: orbitSeek
                    anchors.fill: parent
                    orbitRadius: 152
                    progress: Media.progress
                    playing: Media.playing
                    enabledControl: Media.canSeek
                    onSeekRequested: function(progress) { Media.seekTo(progress); }
                }

                Repeater {
                    model: 36
                    Rectangle {
                        required property int index
                        readonly property real angle: index * Math.PI * 2 / 36
                        readonly property real signal: root.haloBands.length > 0
                            ? Number(root.haloBands[index % root.haloBands.length] || 0) : 0
                        x: resonancePlanet.width / 2 + Math.cos(angle) * 178 - width / 2
                        y: resonancePlanet.height / 2 + Math.sin(angle) * 178 - height / 2
                        width: 3
                        height: 7 + signal * 32
                        radius: 2
                        rotation: angle * 180 / Math.PI + 90
                        color: index % 3 === 0 ? Theme.cyan : index % 3 === 1 ? Theme.accent : Theme.rose
                        opacity: Media.playing ? 0.9 : 0.28
                        Behavior on height { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }
                    }
                }

                Rectangle {
                    id: albumWorld
                    anchors.centerIn: parent
                    width: 264 + root.spectrumEnergy * 16
                    height: 264 + root.spectrumEnergy * 9
                    radius: width * (0.43 + root.spectrumEnergy * 0.07)
                    color: Theme.mantle
                    border.width: 0
                    border.color: Media.playing ? Theme.accentLine : Theme.line
                    clip: true
                    Image {
                        id: planetArt
                        anchors.fill: parent
                        source: Media.artUrl
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: false
                        layer.enabled: true
                    }
                    Rectangle {
                        id: planetMask
                        anchors.fill: parent
                        radius: albumWorld.radius
                        color: "white"
                        visible: false
                        layer.enabled: true
                    }
                    MultiEffect {
                        anchors.fill: parent
                        source: planetArt
                        maskEnabled: true
                        maskSource: planetMask
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: albumWorld.radius
                        gradient: Gradient {
                            GradientStop { position: 0; color: "transparent" }
                            GradientStop { position: 0.62; color: Qt.rgba(Theme.void_.r, Theme.void_.g, Theme.void_.b, 0.08) }
                            GradientStop { position: 1; color: Qt.rgba(Theme.void_.r, Theme.void_.g, Theme.void_.b, 0.82) }
                        }
                    }
                    Text { anchors.centerIn: parent; visible: Media.artUrl.length === 0; text: Media.mediaKind === "VIDEO" ? "󰕧" : "󰎆"; color: Theme.accent; font.family: Theme.fontIcon; font.pixelSize: 70 }
                    Behavior on width { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
                    Behavior on height { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
                    Behavior on radius { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                }

                Rectangle {
                    anchors.horizontalCenter: albumWorld.horizontalCenter
                    anchors.top: albumWorld.bottom
                    anchors.topMargin: -18
                    width: statusLabel.implicitWidth + 28
                    height: 36
                    radius: 18
                    color: Theme.mantle
                    border.width: 0
                    border.color: Media.playing ? Theme.success : Theme.warning
                    Text {
                        id: statusLabel
                        anchors.centerIn: parent
                        text: Media.statusText
                        color: Media.playing ? Theme.success : Theme.warning
                        font.family: Theme.fontText
                        font.pixelSize: 10
                        font.weight: Font.Bold
                    }
                }

                Text {
                    anchors.horizontalCenter: albumWorld.horizontalCenter
                    anchors.top: albumWorld.bottom
                    anchors.topMargin: 26
                    visible: orbitSeek.interacting
                    text: Media.formatTime(orbitSeek.previewProgress * Media.length)
                    color: Theme.accent
                    font.family: Theme.fontMono
                    font.pixelSize: 11
                    font.weight: Font.Bold
                }
            }

            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true; spacing: 11
                Item { Layout.fillHeight: true }
                Text { Layout.fillWidth: true; text: Media.artist; color: Theme.muted; font.family: Theme.fontText; font.pixelSize: 14; font.weight: Font.Bold; elide: Text.ElideRight }
                Text { Layout.fillWidth: true; text: Media.title; color: Theme.moon; font.family: Theme.fontDisplay; font.pixelSize: 40; font.weight: Font.Black; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight; lineHeight: 0.94 }
                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    Rectangle {
                        Layout.preferredHeight: 34; Layout.preferredWidth: Math.min(280, deviceRow.implicitWidth + 20)
                        radius: Theme.radiusSmall; color: Theme.elevated; border.width: 0; border.color: Theme.line
                        RowLayout { id: deviceRow; anchors.centerIn: parent; spacing: 7
                            Text { text: "󰓃"; color: Theme.accent; font.family: Theme.fontIcon; font.pixelSize: 15 }
                            Text { text: Audio.defaultOutputName; color: Theme.moon; font.family: Theme.fontMono; font.pixelSize: 11; font.weight: Font.Bold; elide: Text.ElideRight }
                        }
                    }
                    Text { Layout.fillWidth: true; text: "VIA " + Media.identity.toUpperCase(); color: Theme.lineBright; font.family: Theme.fontMono; font.pixelSize: 11; font.weight: Font.Bold; elide: Text.ElideRight }
                }

                RowLayout {
                    visible: Media.playerCount > 1
                    Layout.fillWidth: true
                    spacing: 5
                    Repeater {
                        model: Media.players.slice(0, 3)
                        Rectangle {
                            required property var modelData
                            Layout.preferredWidth: Math.min(128, playerName.implicitWidth + 18)
                            Layout.preferredHeight: 28
                            radius: 9
                            readonly property bool active: Media.player && Media.player.uniqueId === modelData.uniqueId
                            color: active ? Theme.accentVeil : playerPointer.containsMouse ? Theme.elevated : Theme.barNeutral
                            border.width: 0
                            border.color: active ? Theme.accentLine : Theme.barHairlineHover
                            Text { id: playerName; anchors.centerIn: parent; width: parent.width - 12; text: parent.modelData.identity.toUpperCase(); color: parent.active ? Theme.accent : Theme.muted; font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Bold; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter }
                            MouseArea { id: playerPointer; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Media.selectPlayer(parent.modelData.uniqueId) }
                        }
                    }
                    Item { Layout.fillWidth: true }
                }

                RowLayout {
                    visible: Media.playerVolumeSupported
                    Layout.fillWidth: true
                    spacing: 8
                    Text { text: "PLAYER VOL"; color: Theme.muted; font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 0.8 }
                    Shared.AudioSlider {
                        Layout.fillWidth: true
                        maximumValue: 100
                        stepSize: 2
                        value: Media.playerVolumePercent
                        accentColor: Theme.cyan
                        onValueRequested: function(nextValue) { Media.setPlayerVolume(nextValue); }
                    }
                }

                Shared.MediaWaveform {
                    id: seekWave
                    Layout.fillWidth: true
                    Layout.preferredHeight: 96
                    progress: Media.progress
                    energy: root.spectrumEnergy
                    trackKey: Media.title + "\u001f" + Media.artist
                    enabledControl: Media.canSeek
                    onSeekRequested: function(progress) { Media.seekTo(progress); }
                }
                RowLayout { Layout.fillWidth: true
                    Text { text: Media.formatTime(seekWave.interacting ? seekWave.previewProgress * Media.length : Media.position); color: seekWave.interacting ? Theme.accent : Theme.muted; font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Bold }
                    Item { Layout.fillWidth: true }
                    Text { text: Media.formatTime(Media.length); color: Theme.muted; font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Bold }
                }
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter; spacing: 12
                    TransportButton { glyph: "󰒮"; onActivated: Media.previous() }
                    TransportButton { glyph: "󰑕"; label: "10"; onActivated: Media.seekRelative(-10) }
                    TransportButton { primary: true; glyph: Media.playing ? "󰏤" : "󰐊"; onActivated: Media.toggle() }
                    TransportButton { glyph: "󰒭"; label: "10"; onActivated: Media.seekRelative(10) }
                    TransportButton { glyph: "󰒭"; onActivated: Media.next() }
                }
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 6
                    ModeButton {
                        glyph: "󰒟"
                        label: "SHUFFLE"
                        active: Media.shuffled
                        enabledControl: Media.shuffleSupported
                        onActivated: Media.toggleShuffle()
                    }
                    ModeButton {
                        glyph: Media.loopLabel === "ONE" ? "󰑘" : "󰑖"
                        label: "LOOP " + Media.loopLabel
                        active: Media.loopLabel !== "OFF"
                        enabledControl: Media.loopSupported
                        onActivated: Media.cycleLoop()
                    }
                    ModeButton {
                        glyph: "󰓅"
                        label: Media.rate.toFixed(2).replace(/0$/, "") + "×"
                        active: Math.abs(Media.rate - 1) > 0.01
                        enabledControl: Media.rateSupported
                        onActivated: Media.setRate(Media.rate >= 1.5 ? 0.75 : Media.rate + 0.25)
                    }
                    ModeButton {
                        glyph: "󰹑"
                        label: "RAISE"
                        enabledControl: Media.available && Media.player.canRaise
                        onActivated: Media.raise()
                    }
                }
                Item { Layout.fillHeight: true }
            }
        }
    }

    Component {
        id: lyricsPage
        RowLayout {
            spacing: 14

            Rectangle {
                Layout.preferredWidth: 294
                Layout.fillHeight: true
                radius: Theme.radiusLarge
                color: root.panelTint
                border.width: 0
                border.color: Lyrics.available ? Theme.accentLine : Theme.barHairlineHover
                clip: true

                Image {
                    anchors.fill: parent
                    source: Media.artUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    opacity: 0.68
                }
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.rgba(Theme.void_.r, Theme.void_.g, Theme.void_.b, 0.18) }
                        GradientStop { position: 0.52; color: Qt.rgba(Theme.void_.r, Theme.void_.g, Theme.void_.b, 0.72) }
                        GradientStop { position: 1; color: Theme.void_ }
                    }
                }
                SpectrumField {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 150
                    opacity: 0.46
                    title: ""
                    detail: ""
                }
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 6
                    Item { Layout.fillHeight: true }
                    Text {
                        Layout.fillWidth: true
                        text: Media.title
                        color: Theme.moon
                        font.family: Theme.fontDisplay
                        font.pixelSize: 22
                        font.weight: Font.Black
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: Media.artist + " // " + Media.album
                        color: Theme.muted
                        font.family: Theme.fontMono
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                    Rectangle {
                        Layout.preferredWidth: lyricSource.implicitWidth + 20
                        Layout.preferredHeight: 30
                        radius: 10
                        color: Theme.barNeutral
                        border.width: 0
                        border.color: Theme.barHairlineHover
                        Text {
                            id: lyricSource
                            anchors.centerIn: parent
                            text: Lyrics.busy ? "SEARCHING…"
                                : Lyrics.source.length > 0 ? Lyrics.source : "NO LYRIC LINK"
                            color: Lyrics.busy ? Theme.warning : Lyrics.available ? Theme.success : Theme.muted
                            font.family: Theme.fontMono
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            font.letterSpacing: 0.7
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.radiusLarge
                color: root.panelTint
                border.width: 0
                border.color: Theme.barHairlineHover
                clip: true

                // A track without lyrics carries Tonantzintla's actual mark—not
                // a second, realistic black-hole interpretation. The original
                // asymmetric stream stays intact and takes its colour from the
                // active palette.
                WabiSabiBlackHole {
                    width: parent.width * 0.92
                    height: Math.min(parent.height * 0.52, 350)
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height * 0.055
                    visible: !Lyrics.available
                    diskColor: Theme.accent
                    horizonColor: Theme.void_
                    rotation: -2.4 + root.spectrumEnergy * 1.8
                    scale: 0.985 + root.spectrumEnergy * 0.035
                    opacity: 0.09 + root.spectrumEnergy * 0.06
                }


                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 10
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout { Layout.fillWidth: true; spacing: 1
                            Text { text: "LYRICS"; color: Theme.moon; font.family: Theme.fontDisplay; font.pixelSize: 17; font.weight: Font.Black }
                            Text { text: Lyrics.hasTiming ? "SYNCED TO PLAYER" : "PLAIN TEXT"; color: Lyrics.hasTiming ? Theme.cyan : Theme.muted; font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 0.8 }
                        }
                        ModeButton {
                            glyph: "↻"
                            label: "REFRESH"
                            enabledControl: Media.available && !Lyrics.busy
                            onActivated: Lyrics.refresh(true)
                        }
                    }

                    ListView {
                        id: lyricsList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: Lyrics.available
                        model: Lyrics.lines
                        spacing: 4
                        clip: true
                        currentIndex: Lyrics.currentIndex
                        preferredHighlightBegin: height * 0.36
                        preferredHighlightEnd: height * 0.56
                        highlightRangeMode: ListView.ApplyRange
                        highlightMoveDuration: Settings.motion ? 420 : 0
                        delegate: Rectangle {
                            id: lyricDelegate
                            required property var modelData
                            required property int index
                            readonly property int distance: Lyrics.hasTiming
                                ? Math.abs(index - Lyrics.currentIndex) : 0
                            width: lyricsList.width
                            height: active ? Math.max(76, lyricLine.implicitHeight + 28)
                                : distance === 1 ? Math.max(48, lyricLine.implicitHeight + 20)
                                : lyricLine.implicitHeight + 16
                            radius: 11
                            readonly property bool active: Lyrics.hasTiming && index === Lyrics.currentIndex
                            color: active ? Theme.accentVeil : linePointer.containsMouse ? Theme.barNeutral : "transparent"
                            border.width: 0
                            border.color: Theme.accentLine
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 10
                                Text {
                                    visible: Lyrics.hasTiming
                                    text: Media.formatTime(lyricDelegate.modelData.time)
                                    color: lyricDelegate.active ? Theme.cyan : Theme.lineBright
                                    font.family: Theme.fontMono
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    Layout.alignment: Qt.AlignTop
                                    Layout.topMargin: 3
                                }
                                Text {
                                    id: lyricLine
                                    Layout.fillWidth: true
                                    text: lyricDelegate.modelData.text
                                    color: lyricDelegate.active ? Theme.moon : Theme.muted
                                    font.family: Theme.fontText
                                    font.pixelSize: lyricDelegate.active ? 23
                                        : lyricDelegate.distance === 1 ? 15 : 12
                                    font.weight: lyricDelegate.active ? Font.Black : Font.Normal
                                    wrapMode: Text.Wrap
                                    horizontalAlignment: Text.AlignLeft
                                }
                            }
                            MouseArea {
                                id: linePointer
                                anchors.fill: parent
                                enabled: Lyrics.hasTiming && Media.canSeek
                                hoverEnabled: true
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: Media.seekTo(lyricDelegate.modelData.time / Math.max(1, Media.length))
                            }
                            Behavior on color { ColorAnimation { duration: 180 } }
                            opacity: !Lyrics.hasTiming || active ? 1
                                : Math.max(0.34, 0.82 - distance * 0.10)
                            Behavior on height { NumberAnimation { duration: Settings.motion ? 260 : 0; easing.type: Easing.OutCubic } }
                            Behavior on opacity { NumberAnimation { duration: Settings.motion ? 220 : 0 } }
                        }
                    }

                    Column {
                        visible: !Lyrics.available
                        Layout.alignment: Qt.AlignCenter
                        spacing: 8
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Lyrics.busy ? "󰔟" : Lyrics.instrumental ? "󰎆" : "󰋼"
                            color: Lyrics.busy ? Theme.warning : Theme.accent
                            font.family: Theme.fontIcon
                            font.pixelSize: 42
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Lyrics.busy ? "SEARCHING FOR LYRICS"
                                : Lyrics.instrumental ? "INSTRUMENTAL"
                                : Lyrics.status === "offline" ? "LYRIC ARCHIVE OFFLINE"
                                : Media.available ? "NO LYRICS FOUND FOR THIS TRACK" : "NOTHING PLAYING"
                            color: Theme.moon
                            font.family: Theme.fontMono
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            font.letterSpacing: 0.9
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Lyrics.error.length > 0 ? Lyrics.error : "EMBEDDED MPRIS → CACHE → LRCLIB"
                            color: Theme.muted
                            font.family: Theme.fontMono
                            font.pixelSize: 10
                        }
                    }
                }
            }
        }
    }

    Component {
        id: pitcherPage
        RowLayout {
            spacing: 16

            Rectangle {
                id: pitchInstrument
                Layout.preferredWidth: 438
                Layout.fillHeight: true
                radius: Theme.radiusLarge
                color: root.panelTint
                border.width: 0
                clip: true
                property real shownSemitones: Equalizer.pitchSemitones
                onShownSemitonesChanged: pitchCanvas.requestPaint()
                Behavior on shownSemitones {
                    enabled: !dialPointer.pressed
                    NumberAnimation {
                        duration: Settings.motion ? 420 : 0
                        easing.type: Easing.OutBack
                    }
                }

                Item {
                    id: dialFace
                    width: Math.min(parent.width - 34, parent.height - 34)
                    height: width
                    anchors.centerIn: parent

                    Canvas {
                        id: pitchCanvas
                        anchors.fill: parent
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.reset();
                            ctx.clearRect(0, 0, width, height);
                            const cx = width / 2;
                            const cy = height / 2;
                            const radius = Math.min(width, height) * 0.405;
                            const pitch = pitchInstrument.shownSemitones;

                            // Broken, tilted accretion trails; paint only when
                            // the dial changes, not on an animation timer.
                            ctx.save();
                            ctx.translate(cx, cy);
                            ctx.rotate(-0.23);
                            ctx.scale(1, 0.36);
                            for (let strand = 0; strand < 7; strand++) {
                                ctx.beginPath();
                                ctx.arc(0, 0, radius * (0.58 + strand * 0.038),
                                    0.12 + strand * 0.055, Math.PI * 1.91);
                                ctx.strokeStyle = Qt.rgba(Theme.accent.r, Theme.accent.g,
                                    Theme.accent.b, 0.24 - strand * 0.026);
                                ctx.lineWidth = strand === 0 ? 5 : 1.5;
                                ctx.stroke();
                            }
                            ctx.restore();

                            for (let ring = 0; ring < 2; ring++) {
                                ctx.beginPath();
                                ctx.arc(cx, cy, radius * (0.79 + ring * 0.205), 0, Math.PI * 2);
                                ctx.strokeStyle = Qt.rgba(Theme.moon.r, Theme.moon.g,
                                    Theme.moon.b, 0.055 + ring * 0.018);
                                ctx.lineWidth = 1;
                                ctx.stroke();
                            }

                            for (let note = -12; note < 12; note++) {
                                const angle = -Math.PI / 2 + note / 12 * Math.PI;
                                const major = note === 0 || note % 3 === 0;
                                const inner = radius - (major ? 12 : 5);
                                ctx.beginPath();
                                ctx.moveTo(cx + Math.cos(angle) * inner,
                                    cy + Math.sin(angle) * inner);
                                ctx.lineTo(cx + Math.cos(angle) * radius,
                                    cy + Math.sin(angle) * radius);
                                ctx.strokeStyle = note === 0 ? Theme.rose
                                    : Qt.rgba(Theme.moon.r, Theme.moon.g, Theme.moon.b,
                                        major ? 0.52 : 0.19);
                                ctx.lineWidth = major ? 1.5 : 1;
                                ctx.stroke();
                            }

                            const zeroAngle = -Math.PI / 2;
                            const pitchAngle = zeroAngle + pitch / 12 * Math.PI;
                            ctx.beginPath();
                            ctx.arc(cx, cy, radius * 0.79,
                                Math.min(zeroAngle, pitchAngle),
                                Math.max(zeroAngle, pitchAngle));
                            ctx.strokeStyle = Theme.accent;
                            ctx.lineWidth = 3;
                            ctx.lineCap = "round";
                            ctx.stroke();

                            ctx.beginPath();
                            ctx.moveTo(cx + Math.cos(pitchAngle) * radius * 0.91,
                                cy + Math.sin(pitchAngle) * radius * 0.91);
                            ctx.lineTo(cx + Math.cos(pitchAngle) * radius * 1.035,
                                cy + Math.sin(pitchAngle) * radius * 1.035);
                            ctx.strokeStyle = Theme.moon;
                            ctx.lineWidth = 2;
                            ctx.stroke();

                        }
                    }

                    // The needle head breathes with the live signal as a
                    // scene-graph item: a Canvas repainting at spectrum rate
                    // is exactly what the performance audit removed.
                    Rectangle {
                        readonly property real pitchAngle: -Math.PI / 2
                            + pitchInstrument.shownSemitones / 12 * Math.PI
                        readonly property real reach: Math.min(dialFace.width,
                            dialFace.height) * 0.405 * 0.88
                        width: 7 + root.spectrumEnergy * 4
                        height: width
                        radius: 1
                        rotation: pitchAngle * 180 / Math.PI + 45
                        x: dialFace.width / 2 + Math.cos(pitchAngle) * reach - width / 2
                        y: dialFace.height / 2 + Math.sin(pitchAngle) * reach - height / 2
                        color: Theme.accent
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width * 0.40
                        height: width
                        radius: width / 2
                        color: Theme.void_
                        border.width: 1
                        border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.42)
                        scale: dialPointer.pressed ? 0.94 : 1
                        Column {
                            anchors.centerIn: parent
                            spacing: -3
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: (pitchInstrument.shownSemitones > 0 ? "+" : "")
                                    + Math.round(pitchInstrument.shownSemitones)
                                color: Equalizer.pitchEnabled ? Theme.moon : Theme.muted
                                font.family: Theme.fontDisplay
                                font.pixelSize: 52
                                font.weight: Font.Black
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "SEMITONES"
                                color: Equalizer.pitchEnabled ? Theme.accent : Theme.muted
                                font.family: Theme.fontMono
                                font.pixelSize: 9
                                font.weight: Font.Black
                                font.letterSpacing: 1.2
                            }
                        }
                        Behavior on color { ColorAnimation { duration: Settings.motion ? 180 : 0 } }
                        Behavior on scale { NumberAnimation { duration: Settings.motion ? 150 : 0; easing.type: Easing.OutBack } }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.horizontalCenterOffset: -parent.width * 0.13
                        anchors.bottom: parent.bottom
                        text: "−12"
                        color: Theme.muted
                        font.family: Theme.fontMono
                        font.pixelSize: 10
                        font.weight: Font.Bold
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.horizontalCenterOffset: parent.width * 0.13
                        anchors.bottom: parent.bottom
                        text: "+12"
                        color: Theme.muted
                        font.family: Theme.fontMono
                        font.pixelSize: 10
                        font.weight: Font.Bold
                    }

                    MouseArea {
                        id: dialPointer
                        anchors.fill: parent
                        enabled: Equalizer.available && !Equalizer.busy
                        hoverEnabled: true
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        function updatePitch(px, py) {
                            let angle = Math.atan2(py - height / 2, px - width / 2)
                                + Math.PI / 2;
                            while (angle > Math.PI)
                                angle -= Math.PI * 2;
                            while (angle < -Math.PI)
                                angle += Math.PI * 2;
                            pitchInstrument.shownSemitones = Math.round(angle / Math.PI * 12);
                            pitchCanvas.requestPaint();
                        }
                        onPressed: function(mouse) { updatePitch(mouse.x, mouse.y); }
                        onPositionChanged: function(mouse) {
                            if (pressed)
                                updatePitch(mouse.x, mouse.y);
                        }
                        onReleased: function(mouse) {
                            updatePitch(mouse.x, mouse.y);
                            Equalizer.setPitch(pitchInstrument.shownSemitones,
                                Equalizer.pitchCents);
                        }
                    }

                    Connections {
                        target: Equalizer
                        function onPitchSemitonesChanged() {
                            if (!dialPointer.pressed)
                                pitchInstrument.shownSemitones = Equalizer.pitchSemitones;
                            pitchCanvas.requestPaint();
                        }
                        function onPitchEnabledChanged() { pitchCanvas.requestPaint(); }
                    }
                }

            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.radiusLarge
                color: root.panelTint
                border.width: 0

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 13

                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                                text: "PITCHER"
                                color: Theme.moon
                                font.family: Theme.fontDisplay
                                font.pixelSize: 20
                                font.weight: Font.Black
                            }
                            Text {
                                visible: !Equalizer.available
                                text: "EASY EFFECTS IS REQUIRED"
                                color: Theme.warning
                                font.family: Theme.fontMono
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                font.letterSpacing: 0.7
                            }
                        }
                        ModeButton {
                            glyph: Equalizer.pitchEnabled ? "󰓃" : "󰓄"
                            label: Equalizer.pitchEnabled ? "LIVE" : "BYPASS"
                            active: Equalizer.pitchEnabled
                            enabledControl: Equalizer.available && !Equalizer.busy
                            onActivated: Equalizer.setPitchEnabled(!Equalizer.pitchEnabled)
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 46
                        radius: 14
                        color: Theme.elevated
                        border.width: 0
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 10
                            Rectangle {
                                width: 8; height: 8; radius: 4
                                color: Media.playing ? Theme.success : Theme.warning
                            }
                            Text {
                                Layout.fillWidth: true
                                text: Media.available ? Media.identity.toUpperCase() : "NO PLAYER DETECTED"
                                color: Theme.moon
                                font.family: Theme.fontMono
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Text {
                        text: "INTERVALS"
                        color: Theme.muted
                        font.family: Theme.fontMono
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        font.letterSpacing: 1.1
                    }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 7
                        columnSpacing: 6
                        Repeater {
                            model: [
                                { "label": "½×", "value": -12 },
                                { "label": "−7", "value": -7 },
                                { "label": "−5", "value": -5 },
                                { "label": "0", "value": 0 },
                                { "label": "+5", "value": 5 },
                                { "label": "+7", "value": 7 },
                                { "label": "2×", "value": 12 }
                            ]
                            Rectangle {
                                id: pitchJump
                                required property var modelData
                                readonly property bool active: Math.round(Equalizer.pitchSemitones)
                                    === pitchJump.modelData.value
                                Layout.fillWidth: true
                                Layout.preferredHeight: 38
                                radius: 12
                                color: active ? Theme.accent
                                    : jumpPointer.containsMouse ? Theme.controlHover : Theme.controlRest
                                border.width: 0
                                Text {
                                    anchors.centerIn: parent
                                    text: pitchJump.modelData.label
                                    color: pitchJump.active ? Theme.void_ : Theme.moon
                                    font.family: Theme.fontMono
                                    font.pixelSize: 11
                                    font.weight: Font.Black
                                }
                                MouseArea {
                                    id: jumpPointer
                                    anchors.fill: parent
                                    enabled: Equalizer.available && !Equalizer.busy
                                    hoverEnabled: true
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: Equalizer.setPitch(pitchJump.modelData.value,
                                        Equalizer.pitchCents)
                                }
                            }
                        }
                    }

                    PitchTrack {
                        Layout.fillWidth: true
                        label: "FINE TUNE"
                        suffix: "¢"
                        from: -100; to: 100; step: 1
                        value: Equalizer.pitchCents
                        tone: Theme.rose
                        controlEnabled: Equalizer.available && !Equalizer.busy
                        onCommitted: function(value) {
                            Equalizer.setPitch(Equalizer.pitchSemitones, value);
                        }
                    }
                    PitchTrack {
                        Layout.fillWidth: true
                        label: "MIX"
                        suffix: "%"
                        from: 0; to: 100; step: 1
                        value: Equalizer.pitchMix
                        tone: Theme.cyan
                        controlEnabled: Equalizer.available && !Equalizer.busy
                        onCommitted: function(value) { Equalizer.setPitchMix(value); }
                    }

                    Item { Layout.fillHeight: true }

                    RowLayout {
                        Layout.fillWidth: true
                        Item { Layout.fillWidth: true }
                        ModeButton {
                            glyph: "↺"
                            label: "RESTORE NORMAL AUDIO"
                            enabledControl: Equalizer.available && !Equalizer.busy
                            onActivated: Equalizer.restoreAudio()
                        }
                    }
                }
            }
        }
    }

    Component {
        id: equalizerPage
        ColumnLayout {
            spacing: 12
            RowLayout {
                Layout.fillWidth: true
                ColumnLayout { Layout.fillWidth: true; spacing: 2
                    Text { text: "EQUALIZER"; color: Theme.moon; font.family: Theme.fontDisplay; font.pixelSize: 17; font.weight: Font.Black }
                }
                Rectangle {
                    Layout.preferredWidth: 146; Layout.preferredHeight: 36; radius: Theme.radiusSmall
                    color: Equalizer.available ? Theme.accentVeil : Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.12)
                    border.width: 0; border.color: Equalizer.available ? Theme.accentLine : Theme.warning
                    Row { anchors.centerIn: parent; spacing: 7
                        Rectangle { width: 7; height: 7; radius: 4; color: Equalizer.available ? Theme.success : Theme.warning; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: Equalizer.available ? "EASY EFFECTS READY" : "BACKEND MISSING"; color: Equalizer.available ? Theme.moon : Theme.warning; font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Bold }
                    }
                }
            }
            GridLayout {
                Layout.fillWidth: true; columns: 8; columnSpacing: 6; rowSpacing: 6
                Repeater {
                    model: ["Neutral", "Gravity", "Air", "Dialogue", "Pulse", "Impact", "Lounge", "Orchestra"]
                    Rectangle {
                        id: presetButton
                        required property string modelData
                        readonly property bool active: Equalizer.preset === modelData
                        Layout.fillWidth: true; Layout.preferredHeight: 36; radius: Theme.radiusSmall
                        color: active ? Theme.accent : presetPointer.containsMouse ? Theme.elevated : Theme.mantle
                        border.width: 0; border.color: active ? Theme.accent : Theme.line
                        Text { anchors.centerIn: parent; text: presetButton.modelData.toUpperCase(); color: presetButton.active ? Theme.void_ : Theme.muted; font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Bold }
                        MouseArea { id: presetPointer; anchors.fill: parent; hoverEnabled: true; cursorShape: Equalizer.available ? Qt.PointingHandCursor : Qt.ArrowCursor; enabled: Equalizer.available; onClicked: Equalizer.applyPreset(presetButton.modelData) }
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true; Layout.fillHeight: true
                radius: Theme.radiusLarge; color: Theme.mantle; border.width: 0; border.color: Theme.line
                Row {
                    id: bandRow
                    anchors.fill: parent; anchors.leftMargin: 18; anchors.rightMargin: 18; anchors.topMargin: 14; anchors.bottomMargin: 12
                    spacing: 8
                    Repeater {
                        model: 10
                        Item {
                            id: bandControl
                            required property int index
                            width: (bandRow.width - 9 * bandRow.spacing) / 10; height: bandRow.height
                            property real liveValue: Equalizer.bands[index] || 0
                            property bool adjusting: false
                            Connections { target: Equalizer
                                function onBandsChanged() { if (!bandControl.adjusting) bandControl.liveValue = Equalizer.bands[bandControl.index] || 0; }
                            }
                            ColumnLayout {
                                anchors.fill: parent; spacing: 5
                                Text { Layout.alignment: Qt.AlignHCenter; text: (bandControl.liveValue > 0 ? "+" : "") + Math.round(bandControl.liveValue) + "dB"; color: bandControl.adjusting ? Theme.accent : Theme.moon; font.family: Theme.fontMono; font.pixelSize: 11; font.weight: Font.Bold }
                                Item {
                                    Layout.fillHeight: true; Layout.preferredWidth: 32; Layout.alignment: Qt.AlignHCenter
                                    Rectangle { anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 8; radius: 4; color: Theme.elevated; border.width: 0; border.color: Theme.line }
                                    Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: parent.height / 2; width: 22; height: 1; color: Theme.lineBright }
                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        y: Math.max(0, Math.min(parent.height - height, (1 - (bandControl.liveValue + 12) / 24) * parent.height - height / 2))
                                        width: bandControl.adjusting ? 22 : 18; height: width; radius: width / 2
                                        color: Theme.accent; border.width: 0; border.color: Theme.moon
                                        Behavior on y { enabled: !bandControl.adjusting; NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Equalizer.available ? Qt.SizeVerCursor : Qt.ArrowCursor; enabled: Equalizer.available
                                        function setValue(py) { bandControl.liveValue = Math.max(-12, Math.min(12, 12 - (py / Math.max(1, height)) * 24)); }
                                        onPressed: function(mouse) { bandControl.adjusting = true; setValue(mouse.y); }
                                        onPositionChanged: function(mouse) { if (pressed) setValue(mouse.y); }
                                        onReleased: function(mouse) { setValue(mouse.y); bandControl.adjusting = false; Equalizer.setBand(bandControl.index, bandControl.liveValue); }
                                    }
                                }
                                Text { Layout.alignment: Qt.AlignHCenter; text: root.frequencyLabels[bandControl.index]; color: Theme.muted; font.family: Theme.fontMono; font.pixelSize: 11; font.weight: Font.Bold }
                            }
                        }
                    }
                }
            }
            RowLayout { Layout.fillWidth: true
                Text { text: Equalizer.preset.toUpperCase(); color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Bold }
                Item { Layout.fillWidth: true }
                Text { text: Equalizer.busy ? "SYNCHRONIZING…" : Audio.defaultOutputName; color: Equalizer.busy ? Theme.warning : Theme.success; font.family: Theme.fontMono; font.pixelSize: 11; font.weight: Font.Bold; elide: Text.ElideRight }
            }
        }
    }
}
