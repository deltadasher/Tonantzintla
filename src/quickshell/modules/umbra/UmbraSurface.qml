pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import "../.."
import "../../services"
import "../../components"
import "UmbraLayout.js" as Layout

FocusScope {
    id: root

    property var opticalBackdrop: opticalField
    OpticalBackdrop {
        id: opticalField
        anchors.fill: parent
        scope: "umbra"
        active: root.surfaceActive && background.mode !== "solid"
        viewportSize: Qt.size(root.width, root.height)
        source: background.mode === "solid" ? "" : String(background.actualStillSource)
        sourceKind: background.videoPlaying ? "video" : "image"
        // Prepared Umbra loops have no separate cached still. The provider keeps
        // controls etched while the loop plays rather than decoding another copy.
        previewSource: ""
    }
    readonly property var layout: Layout.normalize(Settings.umbraLayout)
    function hasPlacement(key) { return Settings.umbraLayout && Settings.umbraLayout[key] !== undefined; }
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
    readonly property real horizonSize: Math.min(height * 1.26, width * 0.78)
    // One decoder across lock outputs protects the shared memory budget.
    readonly property bool videoOutput: !root.screenInfo
        || root.screenInfo.name === (Compositor.focusedOutput.length > 0 ? Compositor.focusedOutput
            : Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "")
    readonly property bool surfaceActive: root.previewMode
        ? Umbra.previewActive : Umbra.active
    readonly property real visualEnergy: Math.max(root.authEnergy,
        Umbra.authenticating || Umbra.unlocking ? 1 : Umbra.failed ? 0.76 : 0)
    readonly property bool motionEnabled: Settings.motion && Settings.umbraMotion
    readonly property real contentOpacity: stage(0.10, 0.42) * (1 - root.departure)
    readonly property real clockArrival: stage(0.22, 0.64)
    readonly property real inputArrival: Umbra.password.length > 0 || Umbra.failed || Umbra.authenticating
        ? 1 : stage(0.28, 0.60)
    readonly property real mediaArrival: stage(0.46, 0.84)

    // One linear master timeline; each layer owns a bounded reveal window.
    function curve(value, start, end) {
        const t = Math.max(0, Math.min(1, (value - start) / (end - start)));
        return t * t * t * (t * (t * 6 - 15) + 10);
    }
    function stage(start, end) { return curve(intro, start, end); }
    readonly property real departure: curve(consume, 0.08, 0.46)
    readonly property real plunge: curve(consume, 0.34, 0.96)
    readonly property real recoil: Math.sin(curve(consume, 0, 0.36) * Math.PI)

    function startEntrance() {
        introAnimation.stop();
        intro = motionEnabled ? 0 : 1;
        if (motionEnabled) introDelay.restart();
        focusDelay.restart();
    }

    onMotionEnabledChanged: {
        if (!motionEnabled) {
            introDelay.stop();
            introAnimation.stop();
            intro = 1;
            if (Umbra.unlocking) {
                consumeAnimation.stop();
                consume = 1;
            }
        }
    }
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
            startEntrance();
        }
    }

    onSurfaceActiveChanged: {
        if (root.surfaceActive) {
            startEntrance();
        } else {
            introDelay.stop();
            introAnimation.stop();
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
            if (Umbra.unlocking) {
                introDelay.stop();
                introAnimation.stop();
                root.intro = 1;
                consumeAnimation.restart();
            }
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
        duration: root.motionEnabled ? 2200 : 0
        easing.type: Easing.Linear
    }
    NumberAnimation {
        id: authDecay
        target: root
        property: "authEnergy"
        to: 0
        duration: Settings.motion && Settings.umbraMotion ? 1300 : 0
        easing.type: Easing.OutCubic
    }
    NumberAnimation {
        id: consumeAnimation
        target: root
        property: "consume"
        from: 0
        to: 1
        // Finish before the existing 1460ms authenticated release deadline.
        duration: root.motionEnabled ? 1380 : 0
        easing.type: Easing.Linear
    }
    NumberAnimation {
        id: typingDecay
        target: root
        property: "typingEnergy"
        to: Umbra.password.length > 0 ? 0.34 : 0
        duration: Settings.motion && Settings.umbraMotion ? 760 : 0
        easing.type: Easing.OutCubic
    }

    UmbraBackground {
        id: background
        anchors.fill: parent
        active: root.surfaceActive
        videoEnabled: root.videoOutput
        preview: root.previewMode
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

    Rectangle {
        anchors.fill: parent
        color: Theme.void_
        opacity: 1 - root.stage(0.08, 0.72)
    }

    UmbraField {
        anchors.fill: parent
        focalX: width * (0.69 - root.plunge * 0.19)
        focalY: height * 0.48
        energy: root.visualEnergy
        motionActive: root.surfaceActive
        scale: 1 + (1 - root.stage(0.0, 0.8)) * 0.045 + root.plunge * 0.16
        opacity: root.stage(0.08, 0.72) * (1 - root.departure)
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
        objectName: "umbraFixedHorizon"
        width: root.horizonSize
        height: width
        x: (root.width * (0.69 - root.plunge * 0.19)) - width * 0.5
            + (1 - root.stage(0.08, 0.85)) * root.width * 0.018
        y: root.height * (0.48 + root.plunge * 0.02) - height * 0.5
        deployment: root.intro
        energy: root.visualEnergy + root.recoil * 0.5
        failed: Umbra.failed
        authenticating: Umbra.authenticating
        collapseActive: Umbra.unlocking
        collapseProgress: root.consume
        shock: root.failureShock
        motionActive: root.surfaceActive
        opacity: root.stage(0.0, 0.08)
        scale: (1 + (1 - root.stage(0.05, 0.90)) * 0.12)
            * (1 - root.failureShock * 0.11)
            * (1 - root.recoil * 0.045 + Math.pow(root.plunge, 2.4) * 7.5)
        rotation: 0
        z: root.consume > 0 ? 20 : 0
    }

    Row {
        x: root.pad
        y: root.pad
        spacing: 14 * root.sf
        opacity: root.contentOpacity
        Rectangle {
            width: 24 * root.sf; height: 2 * root.sf
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.accent
        }
        Text {
            text: "UMBRA"
            color: Theme.moon
            font.family: Theme.fontMono
            font.pixelSize: 13 * root.sf
            font.letterSpacing: 6 * root.sf
        }
    }

    Text {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: root.pad
        text: root.previewMode ? "PREVIEW   /   ESC TO CLOSE" : Umbra.stateCode
        color: Theme.muted
        font.family: Theme.fontMono
        font.pixelSize: 10 * root.sf
        font.letterSpacing: 1.5 * root.sf
        opacity: root.contentOpacity
    }

    UmbraPlacement {
        id: clockBox
        objectName: "umbraClock"
        placementRotation: root.layout.clock.rotation
        placementOpacity: root.layout.clock.opacity
        x: root.layout.clock.x * root.width
        y: root.layout.clock.y * root.height + (1 - root.clockArrival) * 28 * root.sf
        width: root.layout.clock.w * root.width
        height: root.hasPlacement("clock") ? root.layout.clock.h * root.height : 240 * root.sf
        visible: root.layout.clock.visible
        opacity: root.clockArrival * (1 - root.departure)
        UmbraClassicClock {
            anchors.fill: parent
            visible: Settings.umbraClockVariant === "classic"
            dateTime: clock.date
        }
        InstrumentClock {
            anchors.fill: parent
            visible: Settings.umbraClockVariant !== "classic"
            active: visible && root.surfaceActive && clockBox.visible
            dateTime: clock.date
            variant: Settings.umbraClockVariant
        }
    }
    UmbraPlacement {
        objectName: "umbraWeather"
        placementRotation: root.layout.weather.rotation
        placementOpacity: root.layout.weather.opacity
        x: root.layout.weather.x * root.width; y: root.layout.weather.y * root.height
        width: root.layout.weather.w * root.width; height: root.layout.weather.h * root.height
        visible: root.layout.weather.visible && Settings.umbraShowWeather && Weather.available
        opacity: root.contentOpacity
        Text {
            anchors.fill: parent
        text: Math.round(Number(Weather.current.temp || 0)) + Weather.unitSymbol + "  /  " + String(Weather.current.condition || "").toUpperCase()
        color: Theme.muted; font.family: Theme.fontMono; font.pixelSize: 10 * root.sf
        fontSizeMode: Text.Fit; minimumPixelSize: 8; elide: Text.ElideRight

        }
    }
    UmbraPlacement {
        objectName: "umbraKeyboard"
        placementRotation: root.layout.keyboard.rotation
        placementOpacity: root.layout.keyboard.opacity
        x: root.layout.keyboard.x * root.width; y: root.layout.keyboard.y * root.height
        width: root.layout.keyboard.w * root.width; height: root.layout.keyboard.h * root.height
        visible: root.layout.keyboard.visible
        opacity: root.contentOpacity
        Text {
            anchors.fill: parent
        text: (Compositor.keyboardLayoutName.length > 0 ? Compositor.keyboardLayoutName : "Keyboard layout unavailable")
            + "  ·  Enter to unlock"
        color: Theme.muted; font.family: Theme.fontMono; font.pixelSize: 10 * root.sf
        fontSizeMode: Text.Fit; minimumPixelSize: 8; elide: Text.ElideRight

        }
    }

    // Password entry is a path through space. The actual TextInput is invisible;
    // each character energizes a node on this trajectory.
    Item {
        objectName: "umbraFixedPassword"
        z: 10 // Editable instruments cannot cover the authentication controls.
        x: root.pad + root.failureOffset
        y: root.height * 0.58
        width: Math.min(root.width * 0.37, 660 * root.sf)
        height: 120 * root.sf
        opacity: root.inputArrival * (1 - root.departure)

        Text {
            x: 0
            y: 0
            text: Umbra.failed || Umbra.authenticating || Umbra.unlocking ? Umbra.statusText
                : passwordInput.text.length > 0 ? "ENTER TO UNLOCK" : "TYPE YOUR PASSWORD"
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
            deployment: root.inputArrival
            energy: root.typingEnergy
            failed: Umbra.failed
            authenticating: Umbra.authenticating
            motionActive: root.surfaceActive
        }

        Rectangle {
            x: parent.width * 0.94 - width * 0.5
            y: 22 * root.sf + (parent.height - 22 * root.sf) * 0.27 - height * 0.5
            width: 44 * root.sf
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
                width: Umbra.authenticating ? parent.width * 0.42 : parent.width * 0.12
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

    Row {
        z: 10
        x: root.pad; y: root.height * .72; spacing: 8
        visible: Umbra.fingerprintAvailable && !root.previewMode
        UmbraFingerprintVisual {
            visible: Settings.umbraFingerprintLook !== "original" || !Settings.umbraFingerprintShowText
            interactive: !root.previewMode
        }
        ActionButton {
            visible: Settings.umbraFingerprintLook === "original" && Settings.umbraFingerprintShowText
            text: Umbra.authenticating && Umbra.authMethod === "fingerprint" ? "Waiting for reader…" : Umbra.failed ? "Retry fingerprint" : "Use fingerprint"
            enabled: !Umbra.authenticating && !Umbra.unlocking
            onClicked: Umbra.submitFingerprint()
        }
        ActionButton {
            text: "Use password"
            visible: Umbra.authenticating && Umbra.authMethod === "fingerprint"
            onClicked: { Umbra.cancelAuthentication(); root.focusInput(); }
        }
    }
    Text {
        x: root.pad; y: root.height - 22
        width: root.width - root.pad * 2
        visible: root.previewMode && background.statusText.length > 0
        text: background.statusText
        color: Theme.muted; font.family: Theme.fontMono; font.pixelSize: 10
        elide: Text.ElideRight
    }

    UmbraPlacement {
        objectName: "umbraBattery"
        placementRotation: root.layout.battery.rotation
        placementOpacity: root.layout.battery.opacity
        visible: root.layout.battery.visible && DeviceState.batteryAvailable
        x: root.hasPlacement("battery") ? root.layout.battery.x * root.width : eventHorizon.x + eventHorizon.width * .13
        y: root.hasPlacement("battery") ? root.layout.battery.y * root.height : eventHorizon.y + eventHorizon.height * .73
        width: root.hasPlacement("battery") ? root.layout.battery.w * root.width : 54 * root.sf
        height: root.hasPlacement("battery") ? root.layout.battery.h * root.height : 54 * root.sf
        opacity: root.contentOpacity
        scale: 0.55 + root.intro * 0.45
        UmbraStatusInstrument { anchors.fill: parent; kind: "battery"; textSize: 10 * root.sf }
    }

    UmbraPlacement {
        id: mediaBox
        visible: root.layout.media.visible && Settings.umbraShowMedia && Media.available
        x: root.hasPlacement("media") ? root.layout.media.x * root.width : root.width - root.pad - width
        y: root.hasPlacement("media") ? root.layout.media.y * root.height : root.height - root.pad - height
        width: root.hasPlacement("media") ? root.layout.media.w * root.width : Math.min(470 * root.sf, root.width * .34)
        height: root.hasPlacement("media") ? root.layout.media.h * root.height : 108 * root.sf
        objectName: "umbraMedia"
        placementRotation: root.layout.media.rotation
        placementOpacity: root.layout.media.opacity
        opacity: root.mediaArrival * (1 - root.departure)
        UmbraMediaInstrument {
            anchors.fill: parent
            active: mediaBox.visible && root.surfaceActive
            phase: eventHorizon.phase
            energy: root.visualEnergy
        }
    }

    Column {
        x: root.pad
        y: root.height - root.pad - height
        spacing: 8 * root.sf
        opacity: root.contentOpacity * 0.8
        Text {
            text: Umbra.userName
            color: Theme.moon
            font.family: Theme.fontDisplay
            font.pixelSize: 16 * root.sf
        }
        Text {
            text: root.previewMode ? "SESSION VEIL / PREVIEW" : "SESSION LOCKED"
            color: Theme.muted
            font.family: Theme.fontMono
            font.pixelSize: 9 * root.sf
            font.letterSpacing: 2 * root.sf
        }
    }

    Rectangle {
        anchors.fill: parent
        z: 30
        color: Theme.void_
        opacity: root.curve(root.consume, 0.86, 0.985)
    }

    SequentialAnimation {
        id: failureAnimation
        ParallelAnimation {
            SequentialAnimation {
                NumberAnimation { target: root; property: "failureOffset"; to: -16 * root.sf; duration: Settings.motion && Settings.umbraMotion ? 45 : 0 }
                NumberAnimation { target: root; property: "failureOffset"; to: 12 * root.sf; duration: Settings.motion && Settings.umbraMotion ? 70 : 0 }
                NumberAnimation { target: root; property: "failureOffset"; to: -8 * root.sf; duration: Settings.motion && Settings.umbraMotion ? 65 : 0 }
                NumberAnimation { target: root; property: "failureOffset"; to: 5 * root.sf; duration: Settings.motion && Settings.umbraMotion ? 60 : 0 }
                NumberAnimation { target: root; property: "failureOffset"; to: 0; duration: Settings.motion && Settings.umbraMotion ? 110 : 0; easing.type: Easing.OutCubic }
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
        precision: SystemClock.Minutes
    }
}
