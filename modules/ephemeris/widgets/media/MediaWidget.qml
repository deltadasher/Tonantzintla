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
    property bool seeking: false
    property real seekPreview: Media.progress
    property real visualPhase: 0
    readonly property real shownProgress: seeking ? seekPreview : Media.progress
    readonly property var frequencyLabels: ["31", "63", "125", "250", "500", "1K", "2K", "4K", "8K", "16K"]

    function focusPrimary() { tabRow.forceActiveFocus(); }
    function updateSeek(mouseX, trackWidth) {
        seekPreview = Math.max(0, Math.min(1, mouseX / Math.max(1, trackWidth)));
    }

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Left) {
            Media.seekRelative(-10); event.accepted = true;
        } else if (event.key === Qt.Key_Right) {
            Media.seekRelative(10); event.accepted = true;
        } else if (event.key === Qt.Key_Space) {
            Media.toggle(); event.accepted = true;
        }
    }

    NumberAnimation on visualPhase {
        from: 0; to: Math.PI * 2; duration: 2400; loops: Animation.Infinite
        running: Media.available && Settings.motion
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
                        { "label": "EQUALIZER", "code": "EQL" }
                    ]
                    Rectangle {
                        id: tabButton
                        required property var modelData
                        required property int index
                        readonly property bool active: root.currentTab === index
                        Layout.preferredWidth: tabButton.index === 0 ? 116 : 98; Layout.preferredHeight: 38
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
                : root.currentTab === 1 ? lyricsPage : equalizerPage
        }
    }

    Component {
        id: nowPlayingPage
        RowLayout {
            spacing: 16
            Item {
                id: resonancePlanet
                Layout.preferredWidth: 350
                Layout.fillHeight: true

                Rectangle {
                    anchors.centerIn: albumWorld
                    width: albumWorld.width + 62
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: 0
                    border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.3)
                    rotation: -8
                }

                Repeater {
                    model: 36
                    Rectangle {
                        required property int index
                        readonly property real angle: index * Math.PI * 2 / 36
                        readonly property real signal: Spectrum.available && Spectrum.values.length > 0
                            ? Spectrum.values[index % Spectrum.values.length]
                            : 0.12 + (Math.sin(root.visualPhase + index * 0.54) + 1) * 0.07
                        x: resonancePlanet.width / 2 + Math.cos(angle) * 154 - width / 2
                        y: resonancePlanet.height / 2 + Math.sin(angle) * 154 - height / 2
                        width: 4
                        height: 8 + signal * 28
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
                    width: 258
                    height: 258
                    radius: width / 2
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
                        radius: width / 2
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
                        radius: width / 2
                        gradient: Gradient {
                            GradientStop { position: 0; color: "transparent" }
                            GradientStop { position: 0.62; color: Qt.rgba(Theme.void_.r, Theme.void_.g, Theme.void_.b, 0.08) }
                            GradientStop { position: 1; color: Qt.rgba(Theme.void_.r, Theme.void_.g, Theme.void_.b, 0.82) }
                        }
                    }
                    Text { anchors.centerIn: parent; visible: Media.artUrl.length === 0; text: Media.mediaKind === "VIDEO" ? "󰕧" : "󰎆"; color: Theme.accent; font.family: Theme.fontIcon; font.pixelSize: 70 }
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
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8
                    text: Spectrum.available ? "LIVE AUDIO" : "NO AUDIO"
                    color: Spectrum.available ? Theme.cyan : Theme.muted
                    font.family: Theme.fontMono
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    font.letterSpacing: 1
                }
            }

            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true; spacing: 11
                Item { Layout.fillHeight: true }
                Text { Layout.fillWidth: true; text: Media.title; color: Theme.moon; font.family: Theme.fontDisplay; font.pixelSize: 27; font.weight: Font.Black; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight }
                Text { Layout.fillWidth: true; text: Media.artist; color: Theme.muted; font.family: Theme.fontText; font.pixelSize: 12; font.weight: Font.Bold; elide: Text.ElideRight }
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
                    Text { text: "PLAYER"; color: Theme.muted; font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 0.8 }
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

                Rectangle {
                    id: seekTrack
                    Layout.fillWidth: true; Layout.preferredHeight: 14
                    radius: 7; color: Theme.line; clip: false
                    Rectangle {
                        width: Math.max(parent.radius * 2, parent.width * root.shownProgress); height: parent.height; radius: parent.radius
                        gradient: Gradient { orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: Theme.cyan }
                            GradientStop { position: 0.52; color: Theme.accent }
                            GradientStop { position: 1; color: Theme.rose }
                        }
                        Behavior on width { enabled: !root.seeking; NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                    }
                    Rectangle {
                        x: Math.max(0, Math.min(parent.width - width, parent.width * root.shownProgress - width / 2))
                        anchors.verticalCenter: parent.verticalCenter
                        width: root.seeking ? 20 : 16; height: width; radius: width / 2
                        color: Theme.moon; border.width: 0; border.color: Theme.accent
                        Behavior on width { NumberAnimation { duration: Theme.motionFast; easing.type: Easing.OutBack } }
                    }
                    MouseArea {
                        anchors.fill: parent; anchors.topMargin: -8; anchors.bottomMargin: -8
                        enabled: Media.canSeek; hoverEnabled: true; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onPressed: function(mouse) { root.seeking = true; root.updateSeek(mouse.x, seekTrack.width); }
                        onPositionChanged: function(mouse) { if (pressed) root.updateSeek(mouse.x, seekTrack.width); }
                        onReleased: function(mouse) { root.updateSeek(mouse.x, seekTrack.width); Media.seekTo(root.seekPreview); root.seeking = false; }
                    }
                }
                RowLayout { Layout.fillWidth: true
                    Text { text: Media.formatTime(root.seeking ? root.seekPreview * Media.length : Media.position); color: Theme.muted; font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Bold }
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
                color: Theme.mantle
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
                color: Theme.mantle
                border.width: 0
                border.color: Theme.barHairlineHover
                clip: true

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
                            required property var modelData
                            required property int index
                            width: lyricsList.width
                            height: lyricLine.implicitHeight + 20
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
                                    text: Media.formatTime(parent.parent.modelData.time)
                                    color: parent.parent.active ? Theme.cyan : Theme.lineBright
                                    font.family: Theme.fontMono
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    Layout.alignment: Qt.AlignTop
                                    Layout.topMargin: 3
                                }
                                Text {
                                    id: lyricLine
                                    Layout.fillWidth: true
                                    text: parent.parent.modelData.text
                                    color: parent.parent.active ? Theme.moon : Theme.muted
                                    font.family: Theme.fontText
                                    font.pixelSize: parent.parent.active ? 15 : 12
                                    font.weight: parent.parent.active ? Font.Bold : Font.Normal
                                    wrapMode: Text.Wrap
                                }
                            }
                            MouseArea {
                                id: linePointer
                                anchors.fill: parent
                                enabled: Lyrics.hasTiming && Media.canSeek
                                hoverEnabled: true
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: Media.seekTo(parent.modelData.time / Math.max(1, Media.length))
                            }
                            Behavior on color { ColorAnimation { duration: 180 } }
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
        id: equalizerPage
        ColumnLayout {
            spacing: 12
            RowLayout {
                Layout.fillWidth: true
                ColumnLayout { Layout.fillWidth: true; spacing: 2
                    Text { text: "TEN-BAND EQUALIZER"; color: Theme.moon; font.family: Theme.fontDisplay; font.pixelSize: 17; font.weight: Font.Black }
                    Text { text: "EASY EFFECTS OUTPUT CURVE // PRESETS APPLY IMMEDIATELY"; color: Theme.muted; font.family: Theme.fontMono; font.pixelSize: 11; font.letterSpacing: 0.9 }
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
                                    id: verticalTrack
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
                Text { text: "ACTIVE CURVE"; color: Theme.muted; font.family: Theme.fontMono; font.pixelSize: 11; font.letterSpacing: 1 }
                Text { text: Equalizer.preset.toUpperCase(); color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Bold }
                Item { Layout.fillWidth: true }
                Text { text: Equalizer.busy ? "SYNCHRONIZING…" : Audio.defaultOutputName; color: Equalizer.busy ? Theme.warning : Theme.success; font.family: Theme.fontMono; font.pixelSize: 11; font.weight: Font.Bold; elide: Text.ElideRight }
            }
        }
    }
}
