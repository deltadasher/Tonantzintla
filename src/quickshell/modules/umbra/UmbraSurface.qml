import QtQuick
import QtQuick.Effects
import Quickshell
import "../.."
import "../../services"

FocusScope {
    id: root

    property bool previewMode: false
    property var screenInfo: null
    property real intro: 0
    property real authEnergy: 0
    property real typingEnergy: 0
    property real failureOffset: 0
    property real failureShock: 0
    property real consume: 0
    readonly property real sf: Math.max(0.72, Math.min(1.35,
        Math.min(width / 1920, height / 1080)))
    readonly property real pad: Math.max(26, width * 0.045)
    readonly property real horizonSize: Math.min(height * 0.90, width * 0.56)
    readonly property bool surfaceActive: root.previewMode
        ? Umbra.previewActive : Umbra.active
    readonly property real visualEnergy: Math.max(root.authEnergy,
        Umbra.authenticating || Umbra.unlocking ? 1 : Umbra.failed ? 0.76 : 0)
    readonly property real contentOpacity: root.intro * (1 - root.consume)
    readonly property string wallpaperPath: Settings.umbraUseWallpaper
        && Settings.wallpaperKind === "image" ? Settings.wallpaperPath : ""
    readonly property url wallpaperSource: wallpaperPath.length > 0
        ? (wallpaperPath.indexOf("file:") === 0 ? wallpaperPath : "file://" + wallpaperPath)
        : Qt.resolvedUrl("../../../assets/wallpapers/umbra-array.png")

    signal dismissPreview()

    function focusInput() {
        passwordInput.forceActiveFocus();
    }

    function submitInput() {
        Umbra.submit();
        if (previewMode)
            previewReset.restart();
    }

    Component.onCompleted: {
        if (root.surfaceActive) {
            introDelay.restart();
            focusDelay.restart();
        }
    }

    onSurfaceActiveChanged: {
        if (root.surfaceActive) {
            root.intro = 0;
            introDelay.restart();
            focusDelay.restart();
        } else {
            introDelay.stop();
            focusDelay.stop();
            root.intro = 0;
        }
    }

    Connections {
        target: Umbra
        function onEventSerialChanged() {
            root.authEnergy = 1;
            authDecay.restart();
            if (Umbra.failed)
                failureAnimation.restart();
            focusDelay.restart();
        }
        function onPasswordChanged() {
            if (passwordInput.text !== Umbra.password)
                passwordInput.text = Umbra.password;
            root.typingEnergy = Umbra.password.length > 0 ? 1 : 0;
            typingDecay.restart();
        }
        function onUnlockingChanged() {
            if (Umbra.unlocking)
                consumeAnimation.restart();
            else {
                consumeAnimation.stop();
                root.consume = 0;
            }
        }
    }

    Timer {
        id: introDelay
        interval: 20
        onTriggered: introAnimation.restart()
    }
    Timer {
        id: focusDelay
        interval: 90
        onTriggered: root.focusInput()
    }
    Timer {
        id: previewReset
        interval: 1200
        onTriggered: Umbra.clearInput()
    }

    NumberAnimation {
        id: introAnimation
        target: root
        property: "intro"
        to: 1
        duration: Settings.motion && Settings.umbraMotion ? 1180 : 0
        easing.type: Easing.OutExpo
    }
    NumberAnimation {
        id: authDecay
        target: root
        property: "authEnergy"
        to: 0
        duration: Settings.motion && Settings.umbraMotion ? 1300 : 0
        easing.type: Easing.OutCubic
    }
    SequentialAnimation {
        id: consumeAnimation
        NumberAnimation {
            target: root; property: "consume"; from: 0; to: 0.08
            duration: Settings.motion && Settings.umbraMotion ? 170 : 0
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root; property: "consume"; to: 0.16
            duration: Settings.motion && Settings.umbraMotion ? 280 : 0
            easing.type: Easing.InOutCubic
        }
        NumberAnimation {
            target: root; property: "consume"; to: 1
            duration: Settings.motion && Settings.umbraMotion ? 930 : 0
            easing.type: Easing.InCubic
        }
    }
    NumberAnimation {
        id: typingDecay
        target: root
        property: "typingEnergy"
        to: Umbra.password.length > 0 ? 0.34 : 0
        duration: Settings.motion && Settings.umbraMotion ? 760 : 0
        easing.type: Easing.OutCubic
    }

    Image {
        id: wallpaper
        anchors.fill: parent
        source: root.wallpaperSource
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
    }

    MultiEffect {
        anchors.fill: parent
        source: wallpaper
        visible: Settings.umbraBlurWallpaper
        blurEnabled: true
        blur: 0.68
        blurMax: 64
        saturation: -0.25
        brightness: -0.08
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.void_
        opacity: Settings.umbraBlurWallpaper ? 0.62 : 0.73
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Qt.rgba(Theme.void_.r, Theme.void_.g, Theme.void_.b, 0.94) }
            GradientStop { position: 0.44; color: Qt.rgba(Theme.mantle.r, Theme.mantle.g, Theme.mantle.b, 0.46) }
            GradientStop { position: 0.76; color: Qt.rgba(Theme.void_.r, Theme.void_.g, Theme.void_.b, 0.18) }
            GradientStop { position: 1; color: Qt.rgba(Theme.void_.r, Theme.void_.g, Theme.void_.b, 0.72) }
        }
    }

    UmbraField {
        anchors.fill: parent
        focalX: width * 0.75
        focalY: height * 0.48
        energy: root.visualEnergy
        motionActive: root.surfaceActive
        opacity: root.contentOpacity
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.danger
        opacity: Umbra.failed ? 0.055 : 0
        Behavior on opacity {
            NumberAnimation { duration: Settings.motion && Settings.umbraMotion ? 180 : 0 }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.focusInput()
    }

    // The event horizon is intentionally displaced into the right third. It is
    // scenery, status instrument, and authentication feedback simultaneously.
    UmbraEventHorizon {
        id: eventHorizon
        width: root.horizonSize
        height: width
        x: (root.width * (0.73 - root.consume * 0.23)) - width * 0.5
            + (1 - root.intro) * root.width * 0.20
        y: root.height * (0.48 + root.consume * 0.02) - height * 0.5
        deployment: root.intro
        energy: root.visualEnergy
        failed: Umbra.failed
        authenticating: Umbra.authenticating
        collapseActive: Umbra.unlocking
        collapseProgress: root.consume
        shock: root.failureShock
        motionActive: root.surfaceActive
        opacity: root.intro
        scale: (0.38 + root.intro * 0.62)
            * (1 - root.failureShock * 0.11)
            * (1 + Math.pow(root.consume, 1.45) * 5.9)
        rotation: (1 - root.intro) * -28 + root.consume * 26
            + root.failureShock * -9
        z: root.consume > 0 ? 20 : 0
    }

    Rectangle {
        x: root.pad
        y: root.pad
        width: 9 * root.sf
        height: 54 * root.sf
        color: Umbra.failed ? Theme.danger : Theme.accent
        opacity: root.contentOpacity * 0.76
        transform: Translate { x: (1 - root.intro) * -32 * root.sf }
    }

    Text {
        visible: root.previewMode
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: root.pad
        anchors.topMargin: root.pad
        text: "ESC"
        color: Theme.muted
        font.family: Theme.fontMono
        font.pixelSize: 12 * root.sf
        font.weight: Font.Bold
        opacity: root.contentOpacity * 0.74
    }

    // Time is a vertical fracture rather than a centered hero clock.
    Item {
        x: root.pad + (1 - root.intro) * -90 * root.sf
        y: root.height * 0.145
        width: Math.min(root.width * 0.28, 470 * root.sf)
        height: 360 * root.sf
        opacity: root.contentOpacity

        Rectangle {
            x: 0
            y: 6 * root.sf
            width: 9 * root.sf
            height: 272 * root.sf
            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.70)
        }
        Text {
            x: 28 * root.sf
            y: -20 * root.sf
            text: Qt.formatDateTime(clock.date, "HH")
            color: Theme.moon
            font.family: Theme.fontDisplay
            font.pixelSize: 150 * root.sf
            font.weight: Font.Medium
            font.letterSpacing: -3 * root.sf
        }
        Text {
            x: 28 * root.sf
            y: 112 * root.sf
            text: Qt.formatDateTime(clock.date, "mm")
            color: Theme.moon
            font.family: Theme.fontDisplay
            font.pixelSize: 150 * root.sf
            font.weight: Font.Medium
            font.letterSpacing: -3 * root.sf
        }
        Text {
            x: 30 * root.sf
            y: 292 * root.sf
            text: Qt.formatDateTime(clock.date, "dddd / MMMM dd").toUpperCase()
            color: Theme.muted
            font.family: Theme.fontMono
            font.pixelSize: 10 * root.sf
            font.letterSpacing: 1.15 * root.sf
        }
        Text {
            visible: Settings.umbraShowWeather && Weather.available
            x: 30 * root.sf
            y: 320 * root.sf
            text: Math.round(Number(Weather.current.temp || 0)) + Weather.unitSymbol
                + "  /  " + String(Weather.current.condition || "LOADING").toUpperCase()
            color: Theme.cyan
            font.family: Theme.fontMono
            font.pixelSize: 10 * root.sf
            font.weight: Font.DemiBold
        }
    }

    // Password entry is a path through space. The actual TextInput is invisible;
    // each character energizes a node on this trajectory.
    Item {
        x: root.pad + root.failureOffset
        y: root.height * 0.58 + (1 - root.intro) * 95 * root.sf
        width: Math.min(root.width * 0.59, 1080 * root.sf)
        height: Math.min(root.height * 0.30, 300 * root.sf)
        opacity: root.contentOpacity

        Text {
            x: 0
            y: 0
            visible: Umbra.failed || Umbra.authenticating
            text: Umbra.statusText
            color: Umbra.failed ? Theme.danger
                : Umbra.authenticating ? Theme.cyan : Theme.muted
            font.family: Theme.fontMono
            font.pixelSize: 12 * root.sf
            font.weight: Font.Bold
        }

        UmbraTrajectory {
            id: trajectory
            x: 0
            y: 22 * root.sf
            width: parent.width
            height: parent.height - 22 * root.sf
            count: passwordInput.text.length
            maxNodes: 32
            deployment: root.intro
            energy: root.typingEnergy
            failed: Umbra.failed
            authenticating: Umbra.authenticating
            motionActive: root.surfaceActive
        }

        Rectangle {
            x: parent.width * 0.94 - width * 0.5
            y: 22 * root.sf + (parent.height - 22 * root.sf) * 0.27 - height * 0.5
            width: (Umbra.authenticating ? 84 : 70) * root.sf
            height: width
            radius: width / 2
            color: Umbra.failed ? Theme.danger
                : passwordInput.text.length > 0 ? Theme.accent : Theme.elevated
            scale: 1 + root.visualEnergy * 0.08

            Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 180 } }
            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }

            Rectangle {
                anchors.centerIn: parent
                width: Umbra.authenticating ? parent.width * 0.42 : parent.width * 0.16
                height: width
                radius: width / 2
                color: passwordInput.text.length > 0 || Umbra.failed ? Theme.void_ : Theme.muted
                opacity: Umbra.authenticating ? 0.72 : 0.82
                Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                enabled: passwordInput.text.length > 0 && !Umbra.authenticating
                onClicked: root.submitInput()
            }
        }

        TextInput {
            id: passwordInput
            x: -2
            y: -2
            width: 1
            height: 1
            z: 0
            color: "transparent"
            selectionColor: "transparent"
            selectedTextColor: "transparent"
            cursorVisible: false
            echoMode: TextInput.Password
            passwordCharacter: "●"
            enabled: !Umbra.authenticating && !Umbra.unlocking
            inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
            text: Umbra.password
            opacity: 0.01
            onTextEdited: {
                Umbra.password = text;
                Umbra.failed = false;
                root.typingEnergy = 1;
                typingDecay.restart();
            }
            onAccepted: root.submitInput()
            Keys.onEscapePressed: function(event) {
                event.accepted = true;
                if (root.previewMode)
                    root.dismissPreview();
                else
                    Umbra.clearInput();
            }
            Keys.onPressed: function(event) {
                if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U) {
                    Umbra.clearInput();
                    event.accepted = true;
                }
            }
        }
    }

    Rectangle {
        visible: DeviceState.batteryAvailable
        x: eventHorizon.x + eventHorizon.width * 0.13
        y: eventHorizon.y + eventHorizon.height * 0.73
        width: 54 * root.sf
        height: width
        radius: width / 2
        color: Qt.rgba((DeviceState.batteryLow ? Theme.danger : Theme.cyan).r,
            (DeviceState.batteryLow ? Theme.danger : Theme.cyan).g,
            (DeviceState.batteryLow ? Theme.danger : Theme.cyan).b, 0.15)
        opacity: root.contentOpacity
        scale: 0.55 + root.intro * 0.45

        Text {
            anchors.centerIn: parent
            text: DeviceState.batteryCharging ? "+" : DeviceState.batteryPercent + "%"
            color: DeviceState.batteryLow ? Theme.danger : Theme.cyan
            font.family: Theme.fontMono
            font.pixelSize: 10 * root.sf
            font.weight: Font.Bold
        }
    }

    Item {
        visible: Settings.umbraShowMedia && Media.available
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: root.pad
        anchors.bottomMargin: root.pad
        width: Math.min(470 * root.sf, parent.width * 0.34)
        height: 108 * root.sf
        opacity: root.contentOpacity
        transform: Translate { x: (1 - root.intro) * 70 * root.sf }

        UmbraDisc {
            id: mediaDisc
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 108 * root.sf
            height: width
            artSource: Media.artUrl
            playing: Settings.motion && Settings.umbraMotion && Media.playing
            phase: eventHorizon.phase
            energy: root.visualEnergy
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Media.toggle()
            }
        }

        Text {
            anchors.right: mediaDisc.left
            anchors.rightMargin: 22 * root.sf
            y: 25 * root.sf
            width: parent.width - mediaDisc.width - 30 * root.sf
            horizontalAlignment: Text.AlignRight
            text: Media.title
            color: Theme.moon
            font.family: Theme.fontDisplay
            font.pixelSize: 15 * root.sf
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Rectangle {
            anchors.right: mediaDisc.left
            anchors.rightMargin: 22 * root.sf
            y: 60 * root.sf
            width: (parent.width - mediaDisc.width - 30 * root.sf) * Media.progress
            height: 7 * root.sf
            radius: height / 2
            color: Theme.rose
            Behavior on width { NumberAnimation { duration: 700; easing.type: Easing.Linear } }
        }

        Row {
            anchors.right: mediaDisc.left
            anchors.rightMargin: 22 * root.sf
            y: 78 * root.sf
            spacing: 12 * root.sf

            Repeater {
                model: ["‹", Media.playing ? "Ⅱ" : "▶", "›"]
                Rectangle {
                    required property string modelData
                    required property int index
                    width: 32 * root.sf
                    height: width
                    radius: width / 2
                    color: controlPointer.containsMouse
                        ? (index === 1 ? Theme.accent : Theme.elevated)
                        : index === 1 ? Theme.accentVeil : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: parent.modelData
                        color: parent.index === 1 && controlPointer.containsMouse
                            ? Theme.void_ : Theme.moon
                        font.family: Theme.fontDisplay
                        font.pixelSize: 16 * root.sf
                        font.weight: Font.Bold
                    }
                    MouseArea {
                        id: controlPointer
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (parent.index === 0) Media.previous();
                            else if (parent.index === 1) Media.toggle();
                            else Media.next();
                        }
                    }
                    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        z: 30
        color: Theme.void_
        opacity: Math.max(0, (root.consume - 0.80) / 0.20)
    }

    SequentialAnimation {
        id: failureAnimation
        ParallelAnimation {
            SequentialAnimation {
                NumberAnimation { target: root; property: "failureOffset"; to: -16 * root.sf; duration: 45 }
                NumberAnimation { target: root; property: "failureOffset"; to: 12 * root.sf; duration: 70 }
                NumberAnimation { target: root; property: "failureOffset"; to: -8 * root.sf; duration: 65 }
                NumberAnimation { target: root; property: "failureOffset"; to: 5 * root.sf; duration: 60 }
                NumberAnimation { target: root; property: "failureOffset"; to: 0; duration: 110; easing.type: Easing.OutCubic }
            }
            SequentialAnimation {
                NumberAnimation {
                    target: root; property: "failureShock"; from: 0; to: 1
                    duration: Settings.motion && Settings.umbraMotion ? 95 : 0
                    easing.type: Easing.OutExpo
                }
                NumberAnimation {
                    target: root; property: "failureShock"; to: 0
                    duration: Settings.motion && Settings.umbraMotion ? 720 : 0
                    easing.type: Easing.OutElastic
                }
            }
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }
}
