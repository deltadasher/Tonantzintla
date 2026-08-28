import QtQuick 2.15

Rectangle {
    id: root

    width: 1920
    height: 1080
    color: voidColor
    focus: true

    property color voidColor: config.voidColor
    property color mantle: config.mantle
    property color surface: config.surface
    property color foreground: config.foreground
    property color muted: config.muted
    property color accent: config.accent
    property color secondary: config.secondary
    property color danger: config.danger
    property int currentUserIndex: 0
    property int currentSessionIndex: sessionModel.lastIndex >= 0
        ? sessionModel.lastIndex : 0
    property bool authenticating: false
    property bool failed: false
    property bool succeeded: false
    property bool loginQueued: false
    property real intro: 0
    property real capture: 0
    property real shock: 0
    property real identityPhase: 0
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
            successSequence.restart();
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
        running: root.visible
    }

    SequentialAnimation {
        id: preAuthSequence
        NumberAnimation {
            target: root
            property: "capture"
            to: 0.82
            duration: 760
            easing.type: Easing.InCubic
        }
        ScriptAction {
            script: {
                if (!root.loginQueued)
                    return;
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
        id: successSequence
        NumberAnimation {
            target: root
            property: "capture"
            to: 0.94
            duration: 120
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root
            property: "capture"
            to: 1
            duration: 260
            easing.type: Easing.InCubic
        }
    }

    SequentialAnimation {
        id: identityPulse
        NumberAnimation { target: identityBody; property: "scale"; to: 0.72; duration: 100 }
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
        NumberAnimation { target: sessionBody; property: "scale"; to: 0.76; duration: 90 }
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

    UmbraField {
        z: -8
        anchors.fill: parent
        accent: root.accent
        secondary: root.secondary
        energy: Math.min(1, root.passwordCount / 12)
        focalX: root.width * 0.75
        focalY: root.height * 0.48
        opacity: root.intro * 0.62 * (1 - root.capture * 0.72)
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.focusInput()
    }

    UmbraHorizon {
        id: horizon
        width: root.horizonSize
        height: width
        x: root.width * (0.75 - root.capture * 0.25) - width / 2
            + (1 - root.intro) * root.width * 0.20
        y: root.height * 0.48 - height / 2
        scale: 0.76 + root.intro * 0.24
        opacity: root.intro
        voidColor: root.voidColor
        accent: root.accent
        secondary: root.secondary
        danger: root.danger
        deployment: root.intro
        energy: Math.min(1, root.passwordCount / 10)
        capture: root.capture
        shock: root.shock
        authenticating: root.authenticating
        failed: root.failed
        success: root.succeeded

        Behavior on x {
            NumberAnimation { duration: 720; easing.type: Easing.InOutCubic }
        }
    }

    // Time is a fracture in the layout rather than a centered hero clock.
    Rectangle {
        x: root.width * 0.043
        y: root.height * 0.175
        width: Math.max(7, 8 * root.sf)
        height: root.height * 0.245
        color: root.failed ? root.danger : root.accent
        opacity: 0.82 * root.intro
    }

    Item {
        id: clockAssembly
        x: root.width * 0.058
        y: root.height * 0.155
        width: Math.round(310 * root.sf)
        height: Math.round(390 * root.sf)
        opacity: root.intro * (1 - root.capture)

        Text {
            id: hourText
            x: Math.sin(root.identityPhase * Math.PI * 2) * 5 * root.sf
            y: Math.cos(root.identityPhase * Math.PI * 2) * 4 * root.sf
            text: Qt.formatTime(new Date(), "HH")
            color: root.foreground
            font.family: "JetBrains Mono"
            font.pixelSize: Math.round(142 * root.sf)
            font.weight: Font.DemiBold
        }

        Text {
            id: minuteText
            x: Math.cos(root.identityPhase * Math.PI * 2 + 0.8) * 6 * root.sf
            y: Math.round(153 * root.sf)
                + Math.sin(root.identityPhase * Math.PI * 2 + 0.8) * 5 * root.sf
            text: Qt.formatTime(new Date(), "mm")
            color: root.foreground
            font.family: "JetBrains Mono"
            font.pixelSize: Math.round(142 * root.sf)
            font.weight: Font.DemiBold
        }

        Text {
            id: secondsText
            x: Math.round(215 * root.sf)
                + Math.sin(root.identityPhase * Math.PI * 4) * 9 * root.sf
            y: Math.round(275 * root.sf)
                + Math.cos(root.identityPhase * Math.PI * 4) * 7 * root.sf
            text: Qt.formatTime(new Date(), "ss")
            color: root.accent
            font.family: "JetBrains Mono"
            font.pixelSize: Math.round(22 * root.sf)
            font.weight: Font.Bold
        }

        Text {
            id: dayText
            x: 0
            y: Math.round(334 * root.sf)
            text: Qt.formatDate(new Date(), "dddd").toUpperCase()
            color: root.foreground
            font.family: "JetBrains Mono"
            font.pixelSize: Math.round(14 * root.sf)
            font.weight: Font.Bold
            font.letterSpacing: 1.0
        }

        Text {
            id: dateText
            x: dayText.implicitWidth + Math.round(15 * root.sf)
            y: Math.round(338 * root.sf)
            text: Qt.formatDate(new Date(), "MMM dd").toUpperCase()
            color: root.muted
            font.family: "JetBrains Mono"
            font.pixelSize: Math.round(10 * root.sf)
            font.weight: Font.Medium
            font.letterSpacing: 1.8
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            const now = new Date();
            hourText.text = Qt.formatTime(now, "HH");
            minuteText.text = Qt.formatTime(now, "mm");
            secondsText.text = Qt.formatTime(now, "ss");
            dayText.text = Qt.formatDate(now, "dddd").toUpperCase();
            dateText.text = Qt.formatDate(now, "MMM dd").toUpperCase();
        }
    }

    UmbraTrajectory {
        id: trajectory
        x: root.width * 0.055
        y: root.height * 0.49
        width: root.width * 0.63
        height: root.height * 0.34
        count: root.passwordCount
        accent: root.accent
        secondary: root.secondary
        danger: root.danger
        authenticating: root.authenticating
        failed: root.failed
        deployment: root.intro
        opacity: root.intro * (1 - root.capture)
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

    // Identity and session form their own binary system in the quiet space
    // between the clock and horizon instead of sitting on top of the hero.
    Item {
        id: identityBody
        width: Math.round(122 * root.sf)
        height: Math.round(106 * root.sf)
        x: root.width * 0.45 + Math.cos(root.identityPhase * Math.PI * 2) * 10 - width / 2
        y: root.height * 0.18 + Math.sin(root.identityPhase * Math.PI * 2) * 7 - height / 2
        opacity: root.intro * (1 - root.capture)

        Rectangle {
            id: identityPlanet
            width: Math.round(92 * root.sf)
            height: Math.round(72 * root.sf)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            radius: height / 2
            rotation: identityPointer.containsMouse ? 4 : -8
            color: identityPointer.containsMouse ? root.mantle : root.surface

            Behavior on color { ColorAnimation { duration: 170 } }
            Behavior on rotation {
                NumberAnimation { duration: 260; easing.type: Easing.OutBack }
            }

            // A luminous meridian makes the profile read as an occulted body,
            // not an avatar placeholder.
            Rectangle {
                x: Math.round(10 * root.sf)
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(23 * root.sf)
                height: parent.height * 0.82
                radius: width / 2
                color: identityPointer.containsMouse ? root.secondary : root.accent

                Behavior on color { ColorAnimation { duration: 170 } }
            }

            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: Math.round(11 * root.sf)
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(19 * root.sf)
                height: Math.round(6 * root.sf)
                radius: height / 2
                color: root.secondary
                opacity: 0.72
            }
        }

        Rectangle {
            width: Math.round(14 * root.sf)
            height: width
            radius: width / 2
            color: root.secondary
            x: identityPlanet.x + identityPlanet.width * 0.84
                + Math.cos(root.identityPhase * Math.PI * 4) * 6
            y: identityPlanet.y - height * 0.15
                + Math.sin(root.identityPhase * Math.PI * 4) * 5
        }

        Text {
            anchors.centerIn: identityPlanet
            text: root.currentUserName.length > 0
                ? root.currentUserName.charAt(0).toUpperCase() : "•"
            color: root.foreground
            font.family: "JetBrains Mono"
            font.pixelSize: Math.round(26 * root.sf)
            font.weight: Font.Bold
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: identityPlanet.bottom
            anchors.topMargin: Math.round(9 * root.sf)
            text: root.currentUserName.toUpperCase()
            color: root.foreground
            font.family: "JetBrains Mono"
            font.pixelSize: Math.round(12 * root.sf)
            font.weight: Font.DemiBold
            font.letterSpacing: 1.3
        }

        MouseArea {
            id: identityPointer
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: userModel.count > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.cycleUser(1)
        }
    }

    Item {
        id: sessionBody
        width: Math.round(116 * root.sf)
        height: Math.round(66 * root.sf)
        x: root.width * 0.40 + Math.cos(root.identityPhase * Math.PI * -2) * 8 - width / 2
        y: root.height * 0.27 + Math.sin(root.identityPhase * Math.PI * -2) * 6 - height / 2
        opacity: root.intro * (1 - root.capture)

        // The session selector is a little slingshot body with a particle
        // wake, visually related to the profile without repeating its shape.
        Rectangle {
            x: Math.round(2 * root.sf)
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(7 * root.sf)
            height: width
            radius: width / 2
            color: root.secondary
            opacity: 0.34
        }

        Rectangle {
            x: Math.round(14 * root.sf)
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(11 * root.sf)
            height: width
            radius: width / 2
            color: root.secondary
            opacity: 0.56
        }

        Rectangle {
            id: sessionCapsule
            x: Math.round(31 * root.sf)
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(76 * root.sf)
            height: Math.round(48 * root.sf)
            radius: height / 2
            rotation: sessionPointer.containsMouse ? 5 : -9
            color: sessionPointer.containsMouse ? root.accent : root.secondary

            Behavior on color { ColorAnimation { duration: 170 } }
            Behavior on rotation {
                NumberAnimation { duration: 260; easing.type: Easing.OutBack }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: Math.round(9 * root.sf)
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(8 * root.sf)
                height: parent.height * 0.58
                radius: width / 2
                color: root.voidColor
                opacity: 0.72
            }
        }

        Text {
            anchors.centerIn: sessionCapsule
            text: "↻"
            color: root.voidColor
            font.family: "JetBrains Mono"
            font.pixelSize: Math.round(21 * root.sf)
            font.weight: Font.Bold
        }

        Text {
            anchors.left: parent.right
            anchors.leftMargin: Math.round(14 * root.sf)
            anchors.verticalCenter: parent.verticalCenter
            width: Math.round(220 * root.sf)
            horizontalAlignment: Text.AlignLeft
            text: root.currentSessionName.toUpperCase()
            color: root.foreground
            elide: Text.ElideRight
            font.family: "JetBrains Mono"
            font.pixelSize: Math.round(11 * root.sf)
            font.weight: Font.DemiBold
            font.letterSpacing: 1.1
        }

        MouseArea {
            id: sessionPointer
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: sessionModel.count > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.cycleSession(1)
        }
    }

    Text {
        x: root.width * 0.058
        y: root.height * 0.875
        text: root.failed ? "TRAJECTORY REJECTED"
            : root.authenticating ? "CAPTURE IN PROGRESS"
            : root.passwordCount > 0 ? "PRESS ENTER"
            : ""
        visible: text.length > 0
        color: root.failed ? root.danger : root.muted
        opacity: root.intro * (1 - root.capture)
        font.family: "JetBrains Mono"
        font.pixelSize: Math.round((root.failed ? 15 : 11) * root.sf)
        font.weight: root.failed ? Font.Bold : Font.Medium
        font.letterSpacing: root.failed ? 0.8 : 1.7
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
        anchors.rightMargin: Math.round(48 * root.sf)
        anchors.bottomMargin: Math.round(55 * root.sf)
        spacing: Math.round(17 * root.sf)
        opacity: root.intro * (1 - root.capture)

        OrbitalAction {
            width: Math.round(52 * root.sf)
            height: width
            symbol: "◐"
            label: "Suspend"
            accent: root.secondary
            foreground: root.foreground
            surface: root.surface
            onTriggered: sddm.suspend()
        }

        OrbitalAction {
            width: Math.round(52 * root.sf)
            height: width
            symbol: "↻"
            label: "Reboot"
            accent: root.accent
            foreground: root.foreground
            surface: root.surface
            onTriggered: sddm.reboot()
        }

        OrbitalAction {
            width: Math.round(52 * root.sf)
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
