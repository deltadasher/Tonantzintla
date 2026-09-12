import QtQuick
import QtQuick.Layouts
import "../../../.."
import "../../../../components"
import "../../../../services"

pragma ComponentBehavior: Bound

Item {
    id: root
    property int currentTab: 0
    property int hoveredControl: -1
    property string hoveredKey: ""
    readonly property real preferredSurfaceHeight: currentTab === 1 ? 820 : 640
    readonly property var tabs: ["Overview", "Keys", "Lock"]
    readonly property var bindings: [
        { "keys": "META + ENTER", "name": "Open terminal" },
        { "keys": "META + UP / DOWN", "name": "Change workspace" },
        { "keys": "META + K / J", "name": "Move focus" },
        { "keys": "META + D", "name": "Catalog" },
        { "keys": "META + SHIFT + N", "name": "Settings" },
        { "keys": "META + SHIFT + Q", "name": "Quick telemetry" },
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


    function bindingTokens(keys) {
        return String(keys).toUpperCase().split(/[^A-Z0-9]+/).filter(function(token) {
            return token.length > 0;
        });
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
        if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
            currentTab = (currentTab + (event.key === Qt.Key_Left ? tabs.length - 1 : 1)) % tabs.length;
            event.accepted = true;
        }
    }

    component ManualAction: Rectangle {
        id: action
        property string title: ""
        property string detail: ""
        property bool primary: false
        signal activated()
        implicitHeight: Math.max(64, actionCopy.implicitHeight + 28)
        radius: Theme.radiusMedium
        color: primary ? Theme.accent : pointer.containsMouse || activeFocus ? Theme.controlHover : Theme.controlRest
        border.width: activeFocus ? 1 : 0
        border.color: Theme.accent
        activeFocusOnTab: enabled
        Accessible.role: Accessible.Button
        Accessible.name: title + ". " + detail
        Accessible.onPressAction: activated()
        Keys.onReturnPressed: activated()
        Keys.onSpacePressed: activated()
        ColumnLayout {
            id: actionCopy
            anchors.left: parent.left; anchors.right: parent.right
            anchors.margins: 16; anchors.verticalCenter: parent.verticalCenter
            spacing: 5
            Text {
                Layout.fillWidth: true; text: action.title; wrapMode: Text.Wrap
                color: action.primary ? Theme.void_ : Theme.moon
                font.family: Theme.fontDisplay; font.pixelSize: 16; font.bold: true
            }
            Text {
                Layout.fillWidth: true; visible: text.length > 0
                text: action.detail; wrapMode: Text.Wrap
                color: action.primary ? Theme.void_ : Theme.muted
                font.family: Theme.fontText; font.pixelSize: 12
            }
        }
        MouseArea {
            id: pointer; anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { action.forceActiveFocus(); action.activated(); }
        }
        Behavior on color { ColorAnimation { duration: Settings.motion ? Theme.motionFast : 0 } }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 16
        RowLayout {
            Layout.fillWidth: true
            Text { text: "FLIGHT MANUAL"; color: Theme.moon; font.family: Theme.fontDisplay; font.pixelSize: 22; font.bold: true }
            Item { Layout.fillWidth: true }
            Text { text: Environment.version; color: Theme.muted; font.family: Theme.fontMono; font.pixelSize: 11 }
        }
        Row {
            id: tabRow
            spacing: 6; focus: true
            Repeater {
                model: root.tabs
                Rectangle {
                    id: tab
                    required property string modelData
                    required property int index
                    width: caption.implicitWidth + 28; height: 36; radius: 12
                    color: root.currentTab === index ? Theme.controlActive : mouse.containsMouse || activeFocus ? Theme.controlHover : Theme.controlRest
                    activeFocusOnTab: true
                    Accessible.role: Accessible.PageTab
                    Accessible.name: modelData
                    Accessible.selected: root.currentTab === index
                    Accessible.onPressAction: root.currentTab = index
                    Keys.onReturnPressed: root.currentTab = index
                    Keys.onSpacePressed: root.currentTab = index
                    Text { id: caption; anchors.centerIn: parent; text: tab.modelData; color: root.currentTab === tab.index ? Theme.moon : Theme.muted; font.family: Theme.fontText; font.pixelSize: 13 }
                    Rectangle { anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter; width: parent.width - 22; height: 2; radius: 1; color: Theme.accent; visible: root.currentTab === tab.index }
                    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { tab.forceActiveFocus(); root.currentTab = tab.index; } }
                }
            }
        }
        Loader {
            Layout.fillWidth: true; Layout.fillHeight: true
            sourceComponent: root.currentTab === 0 ? overviewPage : root.currentTab === 1 ? keysPage : lockPage
        }
    }

    Component {
        id: overviewPage
        Flickable {
            id: overview
            clip: true; contentWidth: width; contentHeight: overviewContent.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            ColumnLayout {
                id: overviewContent
                width: overview.width; spacing: 18
                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 190; radius: 24
                    color: Theme.controlRest
                    WabiSabiBlackHole {
                        anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(210, parent.width * 0.38); height: width * 0.72
                        diskColor: Theme.accent; horizonColor: Theme.void_
                    }
                    ColumnLayout {
                        anchors.left: parent.left; anchors.leftMargin: 22; anchors.verticalCenter: parent.verticalCenter
                        width: parent.width * 0.57; spacing: 10
                        Text { Layout.fillWidth: true; text: "TONANTZINTLA"; color: Theme.moon; font.family: Theme.fontDisplay; font.pixelSize: Math.min(28, overview.width / 22); font.bold: true }
                        Text { Layout.fillWidth: true; text: "An observatory you operate."; color: Theme.accent; font.family: Theme.fontText; font.pixelSize: 14; wrapMode: Text.Wrap }
                        Text { Layout.fillWidth: true; text: "Find your way around, learn the controls, or tune your desktop."; color: Theme.muted; font.family: Theme.fontText; font.pixelSize: 12; wrapMode: Text.Wrap }
                    }
                }
                Text { text: "START HERE"; color: Theme.muted; font.family: Theme.fontMono; font.pixelSize: 11; font.letterSpacing: 1 }
                GridLayout {
                    Layout.fillWidth: true; columns: overview.width < 420 ? 1 : 2
                    columnSpacing: 12; rowSpacing: 12
                    ManualAction { Layout.fillWidth: true; title: "Find something"; detail: "Applications and shell actions"; onActivated: ShellState.openEphemeris("apps") }
                    ManualAction { Layout.fillWidth: true; title: "Make it yours"; detail: "Appearance, bar and Niri settings"; onActivated: ShellState.openEphemeris("settings") }
                    ManualAction { Layout.fillWidth: true; title: "Resonance"; detail: "Playback, lyrics and audio controls"; onActivated: ShellState.openEphemeris("media") }
                    ManualAction { Layout.fillWidth: true; title: "Umbra"; detail: "Lock guidance and a safe preview"; onActivated: root.currentTab = 2 }
                }
                Text {
                    Layout.fillWidth: true; wrapMode: Text.Wrap
                    text: "Use Keys for the supplied shortcuts. Your own Niri bindings may differ."
                    color: Theme.muted; font.family: Theme.fontText; font.pixelSize: 12
                }
            }
        }
    }

    Component {
        id: keysPage

        Flickable {
            id: keysView
            clip: true
            contentWidth: width
            contentHeight: keysContent.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            id: keysContent
            width: keysView.width
            spacing: 8

            Text {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: "Supplied shortcuts · your Niri bindings may differ. Hover a key or chord to explore."
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
                    scale: Math.min(1, parent.width / Math.max(1, implicitWidth))
                    transformOrigin: Item.Left
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
                        Layout.preferredHeight: 46
                        radius: 10
                        color: lit ? Theme.controlActive : controlPointer.containsMouse ? Theme.controlHover : Theme.controlRest

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
                                Layout.preferredWidth: Math.min(168, keysView.width * 0.46)
                            }
                            Text {
                                Layout.fillWidth: true
                                text: controlRow.modelData.name
                                wrapMode: Text.Wrap
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
    }


    Component {
        id: lockPage
        Flickable {
            id: lockView
            clip: true; contentWidth: width; contentHeight: lockContent.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            ColumnLayout {
                id: lockContent
                width: lockView.width; spacing: 16
                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 190; radius: 24; color: Theme.controlRest
                    WabiSabiBlackHole {
                        anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(210, parent.width * 0.38); height: width * 0.72
                        diskColor: Theme.accent; horizonColor: Theme.void_
                    }
                    ColumnLayout {
                        anchors.left: parent.left; anchors.leftMargin: 22; anchors.verticalCenter: parent.verticalCenter
                        width: parent.width * 0.54; spacing: 10
                        Text { text: "UMBRA"; color: Theme.moon; font.family: Theme.fontDisplay; font.pixelSize: 32; font.bold: true }
                        Text { Layout.fillWidth: true; text: "Your session, behind the horizon."; color: Theme.muted; font.family: Theme.fontText; font.pixelSize: 14; wrapMode: Text.Wrap }
                    }
                }
                ManualAction {
                    Layout.fillWidth: true
                    title: Settings.idleLockEnabled ? "Automatic lock · " + Settings.idleLockMinutes + " min" : "Automatic lock is off"
                    detail: "Configure the timeout in Lock screen settings."
                    onActivated: { ShellState.settingsSection = "umbra"; ShellState.openEphemeris("settings"); }
                }
                Text {
                    Layout.fillWidth: true; wrapMode: Text.Wrap
                    text: "Preview shows the design without securing the session. Lock now starts the real lock and requires authentication to return."
                    color: Theme.muted; font.family: Theme.fontText; font.pixelSize: 13
                }
                GridLayout {
                    Layout.fillWidth: true; columns: lockView.width < 420 ? 1 : 2
                    columnSpacing: 12; rowSpacing: 12
                    ManualAction { Layout.fillWidth: true; title: "Preview"; detail: "No authentication required"; onActivated: { ShellState.closeEphemeris(); Umbra.preview(); } }
                    ManualAction { Layout.fillWidth: true; primary: true; title: "Lock now"; detail: "Secure the current session"; onActivated: { ShellState.closeEphemeris(); Umbra.launchLock(); } }
                }
                Text {
                    Layout.fillWidth: true; wrapMode: Text.Wrap
                    text: "Idle-inhibiting applications can delay automatic locking. A saved timeout alone does not confirm that a lock was acquired."
                    color: Theme.muted; font.family: Theme.fontText; font.pixelSize: 12
                }
            }
        }
    }
}
