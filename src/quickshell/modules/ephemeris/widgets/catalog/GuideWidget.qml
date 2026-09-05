import QtQuick
import QtQuick.Layouts
import "../../../.."
import "../../../../components"
import "../../../../services"

pragma ComponentBehavior: Bound

Item {
    id: root
    property int currentTab: 0
    property int selectedAtlas: 0
    property int hoveredControl: -1
    property string hoveredKey: ""
    property real orbitPhase: 0
    readonly property var tabs: [
        { "label": "Overview" },
        { "label": "Keys" },
        { "label": "Modules" },
        { "label": "Lock" }
    ]
    readonly property var bindings: [
        { "keys": "META + ENTER", "name": "Open terminal" },
        { "keys": "META + UP / DOWN", "name": "Change workspace" },
        { "keys": "META + K / J", "name": "Move focus" },
        { "keys": "META + D", "name": "Catalog" },
        { "keys": "META + SHIFT + N", "name": "Settings" },
        { "keys": "META + SHIFT + Q", "name": "Quick timer" },
        { "keys": "META + SHIFT + S", "name": "Clipboard snip" },
        { "keys": "META + SHIFT + ESC", "name": "System monitor" },
        { "keys": "SUPER + ALT + L", "name": "Lock with Umbra" },
        { "keys": "ALT + F4", "name": "Close window" }
    ]

    readonly property var keyboardRows: [
        { "shift": 0, "keys": ["ESC", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0"] },
        { "shift": 18, "keys": ["TAB", "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"] },
        { "shift": 28, "keys": ["CAPS", "A", "S", "D", "F", "G", "H", "J", "K", "L"] },
        { "shift": 38, "keys": ["SHIFT", "Z", "X", "C", "V", "B", "N", "M"] },
        { "shift": 10, "keys": ["META", "ALT", "SPACE", "ENTER", "UP", "DOWN"] }
    ]

    readonly property var atlas: [
        { "name": "Aperture", "state": "LIVE", "tone": Theme.success, "group": "suites", "detail": "Compositor workspaces, media, tray, clock" },
        { "name": "Ephemeris", "state": "LIVE", "tone": Theme.success, "group": "suites", "detail": "Calendar, moon phase, and forecast" },
        { "name": "Audio and network", "state": "LIVE", "tone": Theme.success, "group": "suites", "detail": "PipeWire and NetworkManager" },
        { "name": "Resonance", "state": "LIVE", "tone": Theme.success, "group": "suites", "detail": "MPRIS, lyrics, spectrum, pitch, equalizer" },
        { "name": "Focus", "state": "LIVE", "tone": Theme.success, "group": "suites", "detail": "Focus and break cycles with streaks" },
        { "name": "Parallax", "state": "LIVE", "tone": Theme.success, "group": "suites", "detail": "Wallpaper browser and animated walls" },
        { "name": "Umbra", "state": "LIVE", "tone": Theme.success, "group": "suites", "detail": "Multi-output lock with PAM" },
        { "name": "Type", "state": "READY", "tone": Theme.accent, "group": "tools", "detail": "JetBrains Mono with Iosevka icons" },
        { "name": "Chronos", "state": "READY", "tone": Theme.accent, "group": "tools", "detail": "Timers and system stats" },
        { "name": "Optics", "state": "READY", "tone": Theme.accent, "group": "tools", "detail": "Region capture, Satty, recording" }
    ]

    readonly property var atlasGroups: [
        { "title": "Suites", "key": "suites" },
        { "title": "Tools", "key": "tools" }
    ]
    readonly property var launchBodies: [
        { "name": "CATALOG", "key": "META + D", "tab": "apps", "tone": "apps", "xRatio": 0.58, "yRatio": 0.38, "widthRatio": 0.34, "heightPx": 72, "phase": 0.0 },
        { "name": "SETTINGS", "key": "META + SHIFT + N", "tab": "settings", "tone": "settings", "xRatio": 0.10, "yRatio": 0.51, "widthRatio": 0.27, "heightPx": 116, "phase": 1.7 },
        { "name": "RESONANCE", "key": "MEDIA", "tab": "media", "tone": "media", "xRatio": 0.48, "yRatio": 0.64, "widthRatio": 0.40, "heightPx": 78, "phase": 3.2 },
        { "name": "UMBRA", "key": "SUPER + ALT + L", "tab": "lock", "tone": "settings", "xRatio": 0.14, "yRatio": 0.79, "widthRatio": 0.30, "heightPx": 68, "phase": 4.8 }
    ]

    NumberAnimation on orbitPhase {
        from: 0; to: Math.PI * 2; duration: 18000
        loops: Animation.Infinite; running: Settings.motion
    }

    function bindingTokens(keys) {
        return String(keys).toUpperCase().split(/[^A-Z0-9]+/).filter(function(token) {
            return token.length > 0;
        });
    }
    function atlasItems(group) {
        return atlas.filter(function(item) { return item.group === group; });
    }
    function keyBound(label) {
        const token = String(label).toUpperCase();
        return bindings.some(function(binding) {
            return bindingTokens(binding.keys).indexOf(token) >= 0;
        });
    }
    function keyLit(label) {
        const token = String(label).toUpperCase();
        if (hoveredKey.length > 0)
            return token === hoveredKey;
        if (hoveredControl >= 0)
            return bindingTokens(bindings[hoveredControl].keys).indexOf(token) >= 0;
        return keyBound(label);
    }
    function keyWidth(label) {
        if (label === "SPACE")
            return 92;
        if (label === "ENTER" || label === "SHIFT" || label === "CAPS" || label === "META")
            return 56;
        if (label === "TAB" || label === "ALT" || label === "DOWN")
            return 44;
        return 34;
    }
    function focusPrimary() { tabRow.forceActiveFocus(); }
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Left) {
            currentTab = (currentTab + tabs.length - 1) % tabs.length;
            event.accepted = true;
        } else if (event.key === Qt.Key_Right) {
            currentTab = (currentTab + 1) % tabs.length;
            event.accepted = true;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8
        RowLayout {
            Layout.fillWidth: true
            Text { text: "MANUAL"; color: Theme.moon; font.family: Theme.fontDisplay; font.pixelSize: 22; font.weight: Font.Black }
            Item { Layout.fillWidth: true }
            Text { text: Environment.version; color: Theme.muted; font.family: Theme.fontMono; font.pixelSize: 11; font.letterSpacing: 1 }
        }
        Row {
            id: tabRow
            Layout.fillWidth: true
            spacing: 4
            focus: true
            Repeater {
                model: root.tabs
                Item {
                    id: tabButton
                    required property var modelData
                    required property int index
                    readonly property bool active: root.currentTab === index
                    width: tabLabel.implicitWidth + 22; height: 32
                    Text {
                        id: tabLabel; anchors.centerIn: parent; text: tabButton.modelData.label
                        color: tabButton.active ? Theme.moon : Theme.muted
                        font.family: Theme.fontText; font.pixelSize: 13
                        font.weight: tabButton.active ? Font.DemiBold : Font.Normal
                    }
                    Rectangle {
                        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                        height: 2; radius: 1; color: Theme.accent; opacity: tabButton.active ? 1 : 0
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.currentTab = tabButton.index }
                }
            }
        }
        Loader {
            Layout.fillWidth: true; Layout.fillHeight: true
            sourceComponent: root.currentTab === 0 ? overviewPage
                : root.currentTab === 1 ? keysPage
                : root.currentTab === 2 ? modulesPage : lockPage
        }
    }

    Component {
        id: overviewPage
        Item {
            clip: true
            WabiSabiBlackHole {
                width: parent.width * 0.82; height: Math.min(parent.height * 0.42, 330)
                x: -parent.width * 0.10; y: parent.height * 0.06
                diskColor: Theme.accent; horizonColor: Theme.void_
                rotation: Math.sin(root.orbitPhase) * 1.2
                Behavior on rotation { NumberAnimation { duration: 900 } }
            }
            Column {
                x: 8; y: 8; spacing: 4
                Text { text: "TONANTZINTLA"; color: Theme.moon; font.family: Theme.fontDisplay; font.pixelSize: 28; font.weight: Font.Black; font.letterSpacing: 2 }
                Text { text: "A desktop that moves like an instrument."; color: Theme.muted; font.family: Theme.fontText; font.pixelSize: 13 }
            }

            Canvas {
                anchors.fill: parent
                opacity: 0.28
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.strokeStyle = Theme.accent.toString();
                    ctx.lineWidth = 1;
                    ctx.setLineDash([2, 9]);
                    ctx.beginPath();
                    ctx.moveTo(width * 0.30, height * 0.32);
                    ctx.bezierCurveTo(width * 0.92, height * 0.36,
                        width * 0.03, height * 0.68,
                        width * 0.73, height * 0.88);
                    ctx.stroke();
                }
            }

            Repeater {
                model: root.launchBodies
                Rectangle {
                    id: launchBody
                    required property var modelData
                    required property int index
                    readonly property real driftX: Math.sin(root.orbitPhase + modelData.phase) * 7
                    readonly property real driftY: Math.cos(root.orbitPhase * 0.8 + modelData.phase) * 5
                    width: Math.max(150, parent.width * modelData.widthRatio)
                    height: modelData.heightPx
                    x: parent.width * modelData.xRatio + driftX
                    y: parent.height * modelData.yRatio + driftY
                    radius: index === 1 ? height / 2 : Math.min(height / 2, 28)
                    color: launchPointer.containsMouse
                        ? Theme.moduleAccent(modelData.tone) : Theme.controlRest
                    scale: launchPointer.containsMouse ? 1.035 : 1

                    Column {
                        anchors.centerIn: parent; spacing: 3
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: launchBody.modelData.name
                            color: launchPointer.containsMouse ? Theme.void_ : Theme.moon
                            font.family: Theme.fontDisplay; font.pixelSize: 15; font.weight: Font.Black
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: launchBody.modelData.key
                            color: launchPointer.containsMouse ? Theme.void_ : Theme.moduleAccent(launchBody.modelData.tone)
                            font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Bold
                        }
                    }
                    MouseArea {
                        id: launchPointer; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (launchBody.modelData.tab === "lock") {
                                ShellState.closeEphemeris();
                                Umbra.launchLock();
                            } else {
                                ShellState.openEphemeris(launchBody.modelData.tab);
                            }
                        }
                    }
                    Behavior on scale { NumberAnimation { duration: 150 } }
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }
        }
    }

    Component {
        id: keysPage

        ColumnLayout {
            spacing: 8

            Text {
                text: "Lit keys are bound. Hover a key or a chord."
                color: Theme.muted
                font.family: Theme.fontText
                font.pixelSize: 12
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 200

                Column {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Repeater {
                        model: root.keyboardRows
                        Row {
                            id: keyRow
                            required property var modelData
                            spacing: 5
                            leftPadding: modelData.shift

                            Repeater {
                                model: keyRow.modelData.keys
                                Rectangle {
                                    id: keyCap
                                    required property string modelData
                                    readonly property bool bound: root.keyBound(modelData)
                                    readonly property bool lit: root.keyLit(modelData)
                                    width: root.keyWidth(modelData)
                                    height: 34
                                    radius: 8
                                    color: lit ? Theme.accent
                                        : bound ? Theme.accentVeil
                                        : keyPointer.containsMouse ? Theme.controlHover : Theme.controlRest

                                    Text {
                                        anchors.centerIn: parent
                                        text: keyCap.modelData
                                        color: keyCap.lit ? Theme.void_ : keyCap.bound ? Theme.moon : Theme.muted
                                        font.family: Theme.fontMono
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                    }

                                    MouseArea {
                                        id: keyPointer
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onEntered: root.hoveredKey = keyCap.modelData
                                        onExited: if (root.hoveredKey === keyCap.modelData) root.hoveredKey = ""
                                    }

                                    Behavior on color { ColorAnimation { duration: Settings.motion ? Theme.motionFast : 0 } }
                                }
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 3

                Repeater {
                    model: root.bindings
                    Rectangle {
                        id: controlRow
                        required property var modelData
                        required property int index
                        readonly property bool lit: root.hoveredControl === index
                            || (root.hoveredKey.length > 0
                                && root.bindingTokens(modelData.keys).indexOf(root.hoveredKey) >= 0)
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 10
                        color: lit ? Theme.controlActive : controlPointer.containsMouse ? Theme.controlHover : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 14

                            Text {
                                text: controlRow.modelData.keys
                                color: controlRow.lit ? Theme.accent : Theme.muted
                                font.family: Theme.fontMono
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                Layout.preferredWidth: 168
                            }
                            Text {
                                Layout.fillWidth: true
                                text: controlRow.modelData.name
                                color: Theme.moon
                                font.family: Theme.fontText
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                            }
                        }

                        MouseArea {
                            id: controlPointer
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: root.hoveredControl = controlRow.index
                            onExited: if (root.hoveredControl === controlRow.index) root.hoveredControl = -1
                        }

                        Behavior on color { ColorAnimation { duration: Settings.motion ? Theme.motionFast : 0 } }
                    }
                }
            }
        }
    }

    Component {
        id: modulesPage

        Flickable {
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            contentWidth: width
            contentHeight: atlasColumn.height

            Column {
                id: atlasColumn
                width: parent.width
                spacing: 12

                Repeater {
                    model: root.atlasGroups
                    Column {
                        id: atlasGroup
                        required property var modelData
                        width: parent.width
                        spacing: 3

                        Text {
                            text: atlasGroup.modelData.title
                            color: Theme.muted
                            font.family: Theme.fontText
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }

                        Repeater {
                            model: root.atlasItems(atlasGroup.modelData.key)
                            Rectangle {
                                id: atlasRail
                                required property var modelData
                                readonly property int atlasIndex: root.atlas.indexOf(modelData)
                                readonly property bool chosen: root.selectedAtlas === atlasIndex
                                width: atlasGroup.width
                                height: chosen ? 64 : 40
                                radius: 11
                                color: chosen || atlasPointer.containsMouse ? Theme.controlHover : Theme.controlRest

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 10

                                    Rectangle {
                                        width: 8
                                        height: atlasRail.chosen ? 28 : 8
                                        radius: 4
                                        color: atlasRail.modelData.tone
                                        Layout.alignment: Qt.AlignVCenter
                                        Behavior on height {
                                            NumberAnimation {
                                                duration: Settings.motion ? Theme.motionFast : 0
                                                easing.type: Easing.OutCubic
                                            }
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        Text {
                                            Layout.fillWidth: true
                                            text: atlasRail.modelData.name
                                            color: Theme.moon
                                            font.family: Theme.fontDisplay
                                            font.pixelSize: 13
                                            font.weight: Font.DemiBold
                                        }
                                        Text {
                                            visible: atlasRail.chosen
                                            Layout.fillWidth: true
                                            text: atlasRail.modelData.detail
                                            color: Theme.muted
                                            font.family: Theme.fontText
                                            font.pixelSize: 12
                                            wrapMode: Text.WordWrap
                                        }
                                    }

                                    Text {
                                        text: atlasRail.modelData.state
                                        color: atlasRail.modelData.tone
                                        font.family: Theme.fontMono
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        font.letterSpacing: 0.8
                                    }
                                }

                                MouseArea {
                                    id: atlasPointer
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.selectedAtlas = atlasRail.atlasIndex
                                }

                                Behavior on height {
                                    NumberAnimation {
                                        duration: Settings.motion ? Theme.motionNormal : 0
                                        easing.type: Easing.OutCubic
                                    }
                                }
                                Behavior on color { ColorAnimation { duration: Settings.motion ? Theme.motionFast : 0 } }
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: lockPage
        Item {
            clip: true

            Text {
                x: 8; y: 18; text: "UMBRA"; color: Theme.moon
                font.family: Theme.fontDisplay; font.pixelSize: 32; font.weight: Font.Black
            }
            Text {
                x: 10; y: 58; text: "SESSION EVENT HORIZON"; color: Theme.muted
                font.family: Theme.fontMono; font.pixelSize: 10; font.letterSpacing: 1.4
            }

            WabiSabiBlackHole {
                width: parent.width * 1.18; height: Math.min(parent.height * 0.64, 510)
                x: -parent.width * 0.29; y: parent.height * 0.18
                diskColor: Theme.accent; horizonColor: Theme.void_
                rotation: -4 + Math.sin(root.orbitPhase) * 1.5
            }

            Canvas {
                anchors.fill: parent
                opacity: 0.44
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.strokeStyle = Theme.rose.toString();
                    ctx.lineWidth = 2;
                    ctx.beginPath();
                    ctx.moveTo(-20, height * 0.68);
                    ctx.bezierCurveTo(width * 0.22, height * 0.42,
                        width * 0.69, height * 0.86,
                        width + 20, height * 0.56);
                    ctx.stroke();
                }
            }

            Rectangle {
                width: 92; height: 92; radius: 46
                x: parent.width * 0.80 + Math.sin(root.orbitPhase + 1.1) * 5
                y: parent.height * 0.22 + Math.cos(root.orbitPhase + 1.1) * 4
                color: Theme.controlRest
                Column {
                    anchors.centerIn: parent; spacing: 1
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "5"; color: Theme.accent; font.family: Theme.fontDisplay; font.pixelSize: 28; font.weight: Font.Black }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "MIN"; color: Theme.muted; font.family: Theme.fontMono; font.pixelSize: 10; font.weight: Font.Bold }
                }
            }

            Rectangle {
                width: 150; height: 62; radius: 31
                x: parent.width * 0.72 + Math.sin(root.orbitPhase + 3.0) * 6
                y: parent.height * 0.61 + Math.cos(root.orbitPhase + 3.0) * 4
                color: previewPointer.containsMouse ? Theme.accent : Theme.controlRest
                Text { anchors.centerIn: parent; text: "PREVIEW"; color: previewPointer.containsMouse ? Theme.void_ : Theme.moon; font.family: Theme.fontMono; font.pixelSize: 11; font.weight: Font.Bold }
                MouseArea { id: previewPointer; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { ShellState.closeEphemeris(); Umbra.preview(); } }
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            Rectangle {
                width: 188; height: 78; radius: 39
                x: parent.width * 0.12 + Math.sin(root.orbitPhase + 4.6) * 6
                y: parent.height * 0.80 + Math.cos(root.orbitPhase + 4.6) * 4
                color: lockPointer.containsMouse ? Theme.rose : Theme.moon
                Text { anchors.centerIn: parent; text: "LOCK"; color: Theme.void_; font.family: Theme.fontDisplay; font.pixelSize: 18; font.weight: Font.Black; font.letterSpacing: 2 }
                MouseArea { id: lockPointer; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { ShellState.closeEphemeris(); Umbra.launchLock(); } }
                Behavior on color { ColorAnimation { duration: 150 } }
            }
        }
    }
}
