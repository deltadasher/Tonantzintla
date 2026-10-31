import QtQuick 2.15
import "../../../components/identity"
import "../../../components/identity/LockStyles.js" as LockStyles

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
    // The identity's typefaces, password line, buttons and choosers (LockStyles.js).
    readonly property var lockStyle: LockStyles.style(themeIdentity)
    readonly property real buttonSize: Math.max(46, Math.round(50 * sf))
    readonly property real actionSize: Math.max(42, Math.round(48 * sf))

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
        NumberAnimation { target: chooser; property: "scale"; to: 0.97; duration: 100 }
        NumberAnimation {
            target: chooser
            property: "scale"
            to: 1
            duration: 330
            easing.type: Easing.OutBack
        }
    }

    SequentialAnimation {
        id: sessionPulse
        NumberAnimation { target: chooser; property: "scale"; to: 0.97; duration: 90 }
        NumberAnimation {
            target: chooser
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



    SceneLabel {
        x: root.pad; y: root.pad
        text: "Umbra"
        type: root.lockStyle.label
        color: root.foreground
        size: 14
        opacity: root.intro * (1 - root.capture)
    }

    Item {
        x: root.pad; y: root.clockTop
        width: root.formWidth; height: root.timeSize * 1.15 + 34
        opacity: root.intro * (1 - root.capture)
        SceneLabel {
            text: LockStyles.date(root.lockStyle.date, root.clockDate)
            type: root.lockStyle.date
            color: root.accent
            size: 14
        }
        SceneLabel {
            y: 24; width: parent.width
            text: Qt.formatTime(root.clockDate, "HH:mm")
            type: root.lockStyle.clock
            color: root.foreground
            size: root.timeSize
            fontSizeMode: Text.Fit; minimumPixelSize: 32
        }
    }
    Timer {
        interval: 1000; running: root.visible; repeat: true
        onTriggered: root.clockDate = new Date()
    }

    // The password is never drawn: each character adds one glyph to the
    // identity's line, and its shaped button sits where the identity puts it.
    Item {
        id: form
        readonly property string place: root.lockStyle.button.place
        readonly property real gap: 12 * root.sf
        readonly property bool buttonBelow: place === "under" || place === "underEnd"
        readonly property real entryHeight: 90 * root.sf
        x: root.pad
        y: root.inputTop
        width: root.formWidth
        height: entry.y + entry.height + (buttonBelow ? root.buttonSize + gap : 0)
        opacity: root.intro * (1 - root.capture)

        SceneLabel {
            id: prompt
            width: parent.width - (form.place === "over" ? root.buttonSize + form.gap : 0)
            wrapMode: Text.Wrap
            text: root.failed ? "Wrong password"
                : root.authenticating ? "Signing in…"
                : root.passwordCount > 0 ? "Press Enter"
                : "Type your password"
            type: root.lockStyle.label
            color: root.failed ? root.danger : root.muted
            size: 13
            font.weight: root.failed ? Font.Bold : Font.Medium
        }

        SceneEntry {
            id: entry
            readonly property bool side: form.place === "end" || form.place === "start"
            x: form.place === "start" ? root.buttonSize + form.gap : 0
            y: Math.max(prompt.height + 10, form.place === "over" ? root.buttonSize + 4 : 0)
            width: parent.width - (side ? root.buttonSize + form.gap : 0)
            height: form.entryHeight
            kind: root.lockStyle.entry.kind
            cap: root.lockStyle.entry.cap
            count: root.passwordCount
            failed: root.failed
            authenticating: root.authenticating
            motion: root.sceneMotion
            accent: root.accent
            foreground: root.foreground
            danger: root.danger
        }

        SceneButton {
            width: root.buttonSize
            height: width
            x: form.place === "end" || form.place === "underEnd" || form.place === "over" ? parent.width - width : 0
            y: form.place === "over" ? 0
                : form.buttonBelow ? entry.y + entry.height + form.gap
                : entry.y + (entry.height - height) / 2
            shape: root.lockStyle.button.shape
            icon: root.authenticating ? "busy" : "enter"
            label: "Sign in"
            filled: root.failed || root.passwordCount > 0
            accent: root.failed ? root.danger : root.accent
            foreground: root.foreground
            background: root.voidColor
            enabled: root.passwordCount > 0 && !root.authenticating && !root.succeeded
            onTriggered: root.submit()
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

    // User and session are stationary controls in the form, not drifting
    // artwork. Each identity offers them in its own way (lockStyle.chooser).
    Item {
        id: chooser
        x: root.pad; y: root.selectorY
        width: root.formWidth; height: 44
        opacity: root.intro * (1 - root.capture)
        readonly property string mode: root.lockStyle.chooser
        readonly property bool manyUsers: userModel.count > 1
        readonly property bool manySessions: sessionModel.count > 1

        // captions: a caption over each choice.
        Item {
            id: identityBody
            visible: chooser.mode === "captions"
            width: parent.width * .46; height: 44
            SceneLabel { text: "User"; type: root.lockStyle.label; color: root.muted; size: 12 }
            SceneLabel {
                y: 19; width: parent.width
                text: root.currentUserName + (chooser.manyUsers ? "  ›" : "")
                type: root.lockStyle.label
                color: identityPointer.containsMouse ? root.accent : root.foreground
                size: 15; elide: Text.ElideRight
            }
            MouseArea {
                id: identityPointer; anchors.fill: parent; hoverEnabled: true
                cursorShape: chooser.manyUsers ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.cycleUser(1)
            }
        }
        Item {
            id: sessionBody
            visible: chooser.mode === "captions"
            x: parent.width * .52
            width: parent.width * .48; height: 44
            SceneLabel { text: "Session"; type: root.lockStyle.label; color: root.muted; size: 12 }
            SceneLabel {
                y: 19; width: parent.width
                text: root.currentSessionName + (chooser.manySessions ? "  ›" : "")
                type: root.lockStyle.label
                color: sessionPointer.containsMouse ? root.accent : root.foreground
                size: 15; elide: Text.ElideRight
            }
            MouseArea {
                id: sessionPointer; anchors.fill: parent; hoverEnabled: true
                cursorShape: chooser.manySessions ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.cycleSession(1)
            }
        }

        // chips: two soft pills, each naming what it changes.
        Row {
            visible: chooser.mode === "chips"
            spacing: 10
            Repeater {
                model: [["user", root.currentUserName, chooser.manyUsers, 0], ["session", root.currentSessionName, chooser.manySessions, 1]]
                delegate: Rectangle {
                    id: chip
                    required property var modelData
                    width: Math.min(chooser.width * .48, chipText.implicitWidth + 30); height: 40
                    radius: height / 2
                    color: chipPointer.containsMouse ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, .22) : root.surface
                    SceneLabel {
                        id: chipText
                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, chip.width - 24)
                        text: chip.modelData[0] + "  " + chip.modelData[1]
                        type: root.lockStyle.label
                        color: root.foreground; size: 14; elide: Text.ElideRight
                    }
                    MouseArea {
                        id: chipPointer; anchors.fill: parent; hoverEnabled: true
                        cursorShape: chip.modelData[2] ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: chip.modelData[3] === 0 ? root.cycleUser(1) : root.cycleSession(1)
                    }
                }
            }
        }

        // sentence: "Sign in as delta on Niri", with the names to click.
        Row {
            visible: chooser.mode === "sentence"
            y: 10; spacing: 7
            SceneLabel { text: "Sign in as"; type: root.lockStyle.date; color: root.muted; size: 16 }
            SceneLabel {
                text: root.currentUserName; type: root.lockStyle.date; size: 16
                color: userWord.containsMouse ? root.accent : root.foreground
                font.underline: chooser.manyUsers
                MouseArea { id: userWord; anchors.fill: parent; hoverEnabled: true; onClicked: root.cycleUser(1)
                            cursorShape: chooser.manyUsers ? Qt.PointingHandCursor : Qt.ArrowCursor }
            }
            SceneLabel { text: "on"; type: root.lockStyle.date; color: root.muted; size: 16 }
            SceneLabel {
                text: root.currentSessionName; type: root.lockStyle.date; size: 16
                color: sessionWord.containsMouse ? root.accent : root.foreground
                font.underline: chooser.manySessions
                MouseArea { id: sessionWord; anchors.fill: parent; hoverEnabled: true; onClicked: root.cycleSession(1)
                            cursorShape: chooser.manySessions ? Qt.PointingHandCursor : Qt.ArrowCursor }
            }
        }

        // stacked: one line per choice, each led by the identity's shape.
        Column {
            visible: chooser.mode === "stacked"
            y: -6; spacing: 6
            Repeater {
                model: [["user", root.currentUserName, chooser.manyUsers, 0], ["session", root.currentSessionName, chooser.manySessions, 1]]
                delegate: Row {
                    id: line
                    required property var modelData
                    spacing: 10
                    SceneButton {
                        width: 20; height: 20; anchors.verticalCenter: parent.verticalCenter
                        shape: root.lockStyle.button.shape; icon: ""; enabled: false; opacity: 1
                        filled: true; accent: root.accent; foreground: root.foreground; background: root.voidColor
                    }
                    SceneLabel {
                        text: line.modelData[1]; type: root.lockStyle.label; size: 15
                        color: stackPointer.containsMouse ? root.accent : root.foreground
                        MouseArea { id: stackPointer; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: line.modelData[2] ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: line.modelData[3] === 0 ? root.cycleUser(1) : root.cycleSession(1) }
                    }
                    SceneLabel { text: line.modelData[0]; type: root.lockStyle.label; color: root.muted; size: 12
                                 anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }

        // brackets: monospace fields, like a terminal prompt.
        Row {
            visible: chooser.mode === "brackets"
            y: 10; spacing: 18
            Repeater {
                model: [["user", root.currentUserName, chooser.manyUsers, 0], ["session", root.currentSessionName, chooser.manySessions, 1]]
                delegate: SceneLabel {
                    id: field
                    required property var modelData
                    text: modelData[0] + " [ " + modelData[1] + " ]"
                    type: root.lockStyle.label; size: 15
                    color: fieldPointer.containsMouse ? root.accent : root.foreground
                    MouseArea { id: fieldPointer; anchors.fill: parent; hoverEnabled: true
                                cursorShape: field.modelData[2] ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: field.modelData[3] === 0 ? root.cycleUser(1) : root.cycleSession(1) }
                }
            }
        }
    }

    SceneLabel {
        id: statusMessage
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(26 * root.sf)
        type: root.lockStyle.label
        color: root.muted
        opacity: 0
        size: Math.round(12 * root.sf)
    }

    // Power actions in the identity's shape, where the identity places them.
    Row {
        id: actions
        readonly property string place: root.lockStyle.actions
        x: place === "bottomLeft" || place === "formRow" ? root.pad
            : place === "bottomCenter" ? (root.width - width) / 2
            : root.width - root.pad - width
        y: place === "topRight" ? root.pad + 22
            : place === "formRow" ? Math.min(form.y + form.height + 34 * root.sf, root.height - root.pad - height - 16)
            : root.height - root.pad - 16 - height
        spacing: Math.round(17 * root.sf)
        opacity: root.intro * (1 - root.capture)

        Repeater {
            model: [["sleep", "Sleep", 0], ["restart", "Restart", 1], ["power", "Shut down", 2]]
            delegate: SceneButton {
                required property var modelData
                width: root.actionSize
                height: width
                shape: root.lockStyle.button.shape
                icon: modelData[0]
                label: modelData[1]
                showLabel: true
                labelType: root.lockStyle.label
                accent: modelData[2] === 2 ? root.danger : root.accent
                foreground: root.foreground
                background: root.voidColor
                onTriggered: modelData[2] === 0 ? sddm.suspend() : modelData[2] === 1 ? sddm.reboot() : sddm.powerOff()
            }
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
