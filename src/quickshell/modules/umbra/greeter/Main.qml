import QtQuick 2.15
import "../../../components/identity"

Rectangle {
    id: root

    width: 1920
    height: 1080
    color: voidColor
    focus: true

    readonly property string themeIdentity: String(config.themeIdentity || "wabi-sabi")
    readonly property bool themedScene: true
    readonly property bool themeLight: String(config.lockMode || config.themeMode || "dark") === "light"
    readonly property bool sceneMotion: String(config.motion || "true") !== "false"
    property color voidColor: identityScene.item ? identityScene.item.backgroundColor : config.voidColor
    property color mantle: identityScene.item ? Qt.rgba(foreground.r, foreground.g, foreground.b, .16) : config.mantle
    property color surface: identityScene.item ? Qt.rgba(foreground.r, foreground.g, foreground.b, .09) : config.surface
    property color foreground: identityScene.item ? identityScene.item.foregroundColor : config.foreground
    property color muted: identityScene.item ? identityScene.item.mutedColor : config.muted
    property color accent: identityScene.item ? identityScene.item.accentColor : config.accent
    property color secondary: identityScene.item ? identityScene.item.accentColor : config.secondary
    property color danger: identityScene.item ? identityScene.item.dangerColor : config.danger
    property int currentUserIndex: 0
    property int currentSessionIndex: sessionModel.lastIndex >= 0
        ? sessionModel.lastIndex : 0
    property bool authenticating: false
    property bool failed: false
    property bool succeeded: false
    property bool loginQueued: false
    // Authentication is submitted only after the visible capture reaches its
    // terminal frame. SDDM starts the session as soon as it accepts login.
    property bool handoffReady: false
    property real intro: 0
    property real capture: 0
    property real shock: 0
    property real identityPhase: 0
    property date clockDate: new Date()
    readonly property bool portrait: height > width * 1.12
    readonly property real pad: Math.max(26, width * .045)
    readonly property real formWidth: portrait ? width - pad * 2 : Math.min(width * .37, 600 * sf)
    readonly property real clockTop: identityScene.item ? identityScene.item.suggestedClockY : height * (portrait ? .43 : .29)
    readonly property real inputTop: identityScene.item ? identityScene.item.suggestedInputY : height * (portrait ? .65 : .58)
    readonly property real timeSize: portrait ? Math.min(80, width * .17) : 118 * sf
    readonly property real selectorY: clockTop + timeSize * 1.15 + 46
    readonly property real sf: Math.max(0.70, Math.min(1.45,
        Math.min(width / 1920, height / 1080)))
    readonly property real horizonSize: Math.min(height * 0.95, width * 0.58)
    readonly property string currentUserName: {
        if (userModel.count <= 0)
            return "user";
        const value = String(userModel.data(
            userModel.index(currentUserIndex, 0), 257) || "");
        return value.length > 0 && value !== "undefined" ? value : "user";
    }
    readonly property string currentSessionName: sessionProbe.currentItem
        ? sessionProbe.currentItem.sessionName : "Wayland"
    readonly property int passwordCount: passwordField.text.length

    function cycleUser(direction) {
        if (userModel.count <= 1 || authenticating)
            return;
        currentUserIndex = (currentUserIndex + direction + userModel.count)
            % userModel.count;
        passwordField.text = "";
        failed = false;
        identityPulse.restart();
        focusInput();
    }

    function cycleSession(direction) {
        if (sessionModel.count <= 1 || authenticating)
            return;
        currentSessionIndex = (currentSessionIndex + direction + sessionModel.count)
            % sessionModel.count;
        sessionPulse.restart();
        focusInput();
    }

    function focusInput() {
        passwordField.forceActiveFocus();
    }

    function submit() {
        if (authenticating || succeeded || passwordField.text.length === 0)
            return;
        failed = false;
        authenticating = true;
        loginQueued = true;
        handoffReady = false;
        preAuthSequence.restart();
    }

    Component.onCompleted: {
        let preferred = userModel.lastIndex >= 0 ? userModel.lastIndex : 0;
        if (userModel.lastUser && userModel.lastUser.length > 0) {
            for (let i = 0; i < userModel.count; i++) {
                if (String(userModel.data(userModel.index(i, 0), 257))
                        === String(userModel.lastUser)) {
                    preferred = i;
                    break;
                }
            }
        }
        currentUserIndex = preferred;
        introAnimation.restart();
        focusDelay.restart();
    }

    Connections {
        target: sddm

        function onLoginFailed() {
            root.authenticating = false;
            root.loginQueued = false;
            root.handoffReady = false;
            root.failed = true;
            root.succeeded = false;
            passwordField.text = "";
            failureSequence.restart();
            focusDelay.restart();
        }

        function onLoginSucceeded() {
            root.failed = false;
            root.authenticating = false;
            root.succeeded = true;
            root.loginQueued = false;
            // The capture already completed before sddm.login was called.
            // Keep this terminal frame visible until SDDM hands off the
            // session; a post-success animation cannot reliably be seen.
        }

        function onInformationMessage(message) {
            statusMessage.text = String(message || "");
            messageFade.restart();
        }
    }

    Timer {
        id: focusDelay
        interval: 80
        onTriggered: root.focusInput()
    }

    NumberAnimation {
        id: introAnimation
        target: root
        property: "intro"
        from: 0
        to: 1
        duration: 1250
        easing.type: Easing.OutExpo
    }

    NumberAnimation on identityPhase {
        from: 0
        to: 1
        duration: 15000
        loops: Animation.Infinite
        running: root.visible && root.sceneMotion
    }

    SequentialAnimation {
        id: preAuthSequence
        NumberAnimation {
            target: root
            property: "capture"
            to: 1
            duration: 1120
            easing.type: Easing.InCubic
        }
        ScriptAction {
            script: {
                if (!root.loginQueued || root.handoffReady)
                    return;
                root.handoffReady = true;
                sddm.login(root.currentUserName, passwordField.text,
                    root.currentSessionIndex);
            }
        }
    }

    SequentialAnimation {
        id: failureSequence
        ScriptAction { script: root.shock = 1 }
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "shock"
                from: 1
                to: 0
                duration: 1100
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: root
                property: "capture"
                to: 0
                duration: 720
                easing.type: Easing.OutExpo
            }
        }
        PauseAnimation { duration: 900 }
        ScriptAction { script: root.failed = false }
    }

    SequentialAnimation {
        id: identityPulse
        NumberAnimation { target: identityBody; property: "scale"; to: 0.97; duration: 100 }
        NumberAnimation {
            target: identityBody
            property: "scale"
            to: 1
            duration: 330
            easing.type: Easing.OutBack
        }
    }

    SequentialAnimation {
        id: sessionPulse
        NumberAnimation { target: sessionBody; property: "scale"; to: 0.97; duration: 90 }
        NumberAnimation {
            target: sessionBody
            property: "scale"
            to: 1
            duration: 310
            easing.type: Easing.OutBack
        }
    }

    SequentialAnimation {
        id: messageFade
        NumberAnimation { target: statusMessage; property: "opacity"; to: 0.82; duration: 150 }
        PauseAnimation { duration: 2400 }
        NumberAnimation { target: statusMessage; property: "opacity"; to: 0; duration: 300 }
    }

    // SDDM's software renderer turns large Canvas gradients into polygonal
    // bands on some GPUs. Umbra stays intentionally flat here; the field and
    // event horizon provide the depth.
    Rectangle {
        z: -10
        anchors.fill: parent
        color: root.voidColor
    }

    Loader {
        id: identityScene
        anchors.fill: parent
        active: root.themedScene && root.visible
        z: 0
        opacity: root.intro * (1 - root.capture)
        sourceComponent: ThemeScene {
            identity: root.themeIdentity
            accent: config.identityColor || "#e9b872"
            lightMode: root.themeLight
            active: root.visible
            motion: root.sceneMotion
            iconSource: Qt.resolvedUrl("marks/" + root.themeIdentity + ".svg")
        }
    }



    MouseArea {
        anchors.fill: parent
        onClicked: root.focusInput()
    }



    Text {
        x: root.pad; y: root.pad
        text: "Umbra"
        color: root.foreground
        font.family: "sans-serif"; font.pixelSize: 14
        opacity: root.intro * (1 - root.capture)
    }

    Item {
        x: root.pad; y: root.clockTop
        width: root.formWidth; height: root.timeSize * 1.15 + 34
        opacity: root.intro * (1 - root.capture)
        Text {
            text: Qt.formatDate(root.clockDate, "dddd, MMMM d")
            color: root.accent
            font.family: "sans-serif"; font.pixelSize: 13
        }
        Text {
            y: 24; width: parent.width
            text: Qt.formatTime(root.clockDate, "HH:mm")
            color: root.foreground
            font.family: "sans-serif"; font.pixelSize: root.timeSize
            font.weight: Font.Light; font.letterSpacing: -2
            fontSizeMode: Text.Fit; minimumPixelSize: 32
        }
    }
    Timer {
        interval: 1000; running: root.visible; repeat: true
        onTriggered: root.clockDate = new Date()
    }

    UmbraTrajectory {
        x: root.pad
        y: root.inputTop + 24
        width: root.formWidth - 20
        height: 90 * root.sf
        count: root.passwordCount
        motionActive: root.sceneMotion
        foreground: root.foreground
        accent: root.accent
        secondary: root.secondary
        danger: root.danger
        authenticating: root.authenticating
        failed: root.failed
        deployment: root.intro
        opacity: root.intro * (1 - root.capture)
    }

    Rectangle {
        x: root.pad + root.formWidth - width
        y: root.inputTop + 24 + 90 * root.sf * .24 - height / 2
        width: 44; height: 44; radius: 22
        color: root.passwordCount > 0 ? root.accent : root.surface
        border.width: 1
        border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, .24)
        opacity: root.intro * (1 - root.capture)
        Accessible.role: Accessible.Button
        Accessible.name: "Sign in"
        Accessible.onPressAction: root.submit()
        Text {
            anchors.centerIn: parent
            text: root.authenticating ? "·" : "→"
            color: root.passwordCount > 0 ? root.voidColor : root.foreground
            font.family: "sans-serif"; font.pixelSize: 22
        }
        MouseArea {
            anchors.fill: parent
            enabled: root.passwordCount > 0 && !root.authenticating && !root.succeeded
            cursorShape: Qt.PointingHandCursor
            onClicked: root.submit()
        }
    }

    // Resolve SDDM's named session role without guessing its numeric role.
    // The delegate remains non-visual; `currentItem` supplies the label.
    ListView {
        id: sessionProbe
        width: 1
        height: 1
        visible: false
        model: sessionModel
        currentIndex: root.currentSessionIndex

        delegate: Item {
            width: 1
            height: 1
            readonly property string sessionName: String(model.name || "Wayland")
        }
    }

    // User and session are stationary controls in the form, not drifting artwork.
    Item {
        id: identityBody
        x: root.pad; y: root.selectorY
        width: root.formWidth * .46; height: 44
        opacity: root.intro * (1 - root.capture)
        Text {
            text: "User"; color: root.muted
            font.family: "sans-serif"; font.pixelSize: 12
        }
        Text {
            y: 19; width: parent.width
            text: root.currentUserName + (userModel.count > 1 ? "  ›" : "")
            color: identityPointer.containsMouse ? root.accent : root.foreground
            font.family: "sans-serif"; font.pixelSize: 15
            elide: Text.ElideRight
        }
        MouseArea {
            id: identityPointer; anchors.fill: parent; hoverEnabled: true
            cursorShape: userModel.count > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.cycleUser(1)
        }
    }
    Item {
        id: sessionBody
        x: root.pad + root.formWidth * .52; y: root.selectorY
        width: root.formWidth * .48; height: 44
        opacity: root.intro * (1 - root.capture)
        Text {
            text: "Session"; color: root.muted
            font.family: "sans-serif"; font.pixelSize: 12
        }
        Text {
            y: 19; width: parent.width
            text: root.currentSessionName + (sessionModel.count > 1 ? "  ›" : "")
            color: sessionPointer.containsMouse ? root.accent : root.foreground
            font.family: "sans-serif"; font.pixelSize: 15
            elide: Text.ElideRight
        }
        MouseArea {
            id: sessionPointer; anchors.fill: parent; hoverEnabled: true
            cursorShape: sessionModel.count > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.cycleSession(1)
        }
    }

    Text {
        x: root.pad
        y: root.inputTop
        width: root.formWidth
        wrapMode: Text.Wrap
        text: root.failed ? "Wrong password"
            : root.authenticating ? "Signing in…"
            : root.passwordCount > 0 ? "Press Enter"
            : "Type your password"
        visible: text.length > 0
        color: root.failed ? root.danger : root.muted
        opacity: root.intro * (1 - root.capture)
        font.family: "JetBrains Mono"
        font.pixelSize: 13
        font.weight: root.failed ? Font.Bold : Font.Medium
        font.letterSpacing: 0
    }

    Text {
        id: statusMessage
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(26 * root.sf)
        color: root.muted
        opacity: 0
        font.family: "JetBrains Mono"
        font.pixelSize: Math.round(11 * root.sf)
        font.letterSpacing: 1.0
    }

    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: root.pad
        anchors.bottomMargin: root.pad + 16
        spacing: Math.round(17 * root.sf)
        opacity: root.intro * (1 - root.capture)

        OrbitalAction {
            width: Math.max(44, Math.round(52 * root.sf))
            height: width
            symbol: "◐"
            label: "Suspend"
            accent: root.secondary
            foreground: root.foreground
            surface: root.surface
            onTriggered: sddm.suspend()
        }

        OrbitalAction {
            width: Math.max(44, Math.round(52 * root.sf))
            height: width
            symbol: "↻"
            label: "Reboot"
            accent: root.accent
            foreground: root.foreground
            surface: root.surface
            onTriggered: sddm.reboot()
        }

        OrbitalAction {
            width: Math.max(44, Math.round(52 * root.sf))
            height: width
            symbol: "⏻"
            label: "Power"
            accent: root.danger
            foreground: root.foreground
            surface: root.surface
            onTriggered: sddm.powerOff()
        }
    }

    TextInput {
        id: passwordField
        x: -100
        y: -100
        width: 1
        height: 1
        opacity: 0
        echoMode: TextInput.Password
        passwordMaskDelay: 0
        enabled: !root.authenticating && !root.succeeded

        onAccepted: root.submit()
        onTextChanged: {
            if (root.failed && text.length > 0) {
                root.failed = false;
                root.shock = 0;
            }
        }

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                text = "";
                root.failed = false;
                event.accepted = true;
            } else if (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier)) {
                root.cycleSession(1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Backtab
                    || (event.key === Qt.Key_Tab && event.modifiers & Qt.ShiftModifier)) {
                root.cycleSession(-1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Left && event.modifiers & Qt.ControlModifier) {
                root.cycleUser(-1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Right && event.modifiers & Qt.ControlModifier) {
                root.cycleUser(1);
                event.accepted = true;
            }
        }
    }
}
