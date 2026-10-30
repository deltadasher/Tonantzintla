pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import ".."

Item {
    id: root
    property var choices: []
    property var swatches: []
    property string selectedSeed: ""
    property string status: "idle"
    property string error: ""
    property real reveal: 1
    property bool expanded: false
    property bool applying: false
    property bool applied: false
    property bool automatic: true
    property bool canAutomatic: false
    property string applicationError: ""
    property bool customColors: false
    signal chooseSeed(string seed)
    signal applySeed(string seed)
    width: 348; height: 348
    function role(name, fallback) {
        const row = swatches.find(function(item) { return item.role === name; });
        return row ? row.color : fallback;
    }
    Repeater {
        model: root.choices
        delegate: Item {
            id: swatch
            required property string modelData
            required property int index
            readonly property real angle: (210 + index * 120 / Math.max(1, root.choices.length - 1)) * Math.PI / 180
            width: 40; height: 40
            x: root.width / 2 + Math.cos(angle) * 154 - width / 2
            y: root.height / 2 + Math.sin(angle) * 154 - height / 2
            scale: 0.7 + 0.3 * root.reveal; opacity: root.reveal
            activeFocusOnTab: true
            Accessible.role: Accessible.RadioButton
            Accessible.name: "Preview theme from " + modelData
            Accessible.checked: root.selectedSeed === modelData
            function choose() { root.expanded = true; root.chooseSeed(modelData); }
            Accessible.onPressAction: choose()
            Keys.onReturnPressed: choose()
            Keys.onEnterPressed: choose()
            Keys.onSpacePressed: choose()
            Rectangle {
                anchors.centerIn: parent
                width: swatch.activeFocus || pointer.containsMouse ? 30 : 26; height: width; radius: width / 2
                color: swatch.modelData
                border.width: root.selectedSeed === swatch.modelData || swatch.activeFocus ? 3 : 2
                border.color: root.selectedSeed === swatch.modelData || swatch.activeFocus ? Theme.moon : Theme.void_
            }
            MouseArea { id: pointer; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { swatch.forceActiveFocus(); swatch.choose(); } }
        }
    }
    ActionButton {
        anchors.horizontalCenter: parent.horizontalCenter
        y: -38; implicitHeight: 28
        text: root.status === "loading" ? "Sampling colors…" : "Theme source"
        onClicked: root.expanded = !root.expanded
    }
    Rectangle {
        objectName: "themePreviewPanel"
        visible: root.expanded
        readonly property bool fitsAbove: root.y >= height + 52
        x: fitsAbove ? (root.width - width) / 2 : Math.min(root.width + 16, root.parent.width - root.x - width - 12)
        y: fitsAbove ? -height - 52 : 20
        width: 300; height: details.implicitHeight + 24; radius: 12
        color: Theme.mantle
        ColumnLayout {
            id: details; anchors.left: parent.left; anchors.right: parent.right
            anchors.top: parent.top; anchors.margins: 12; spacing: 8
            RowLayout {
                Layout.fillWidth: true
                Text { Layout.fillWidth: true; text: "Theme preview"; color: Theme.moon; font.family: Theme.fontText; font.pixelSize: 12; font.bold: true }
                ActionButton { text: "Close"; implicitHeight: 26; onClicked: root.expanded = false }
            }
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 34; radius: 7
                color: root.role("surface_container", Theme.elevated)
                RowLayout {
                    anchors.fill: parent; anchors.margins: 8
                    Rectangle { width: 18; height: 18; radius: 9; color: root.role("primary", Theme.accent) }
                    Text { Layout.fillWidth: true; text: "Aa · Tonantzintla"; color: root.role("on_surface", Theme.moon); font.family: Theme.fontText; font.pixelSize: 12 }
                    Rectangle { width: 12; height: 12; radius: 6; color: root.role("secondary", Theme.cyan) }
                    Rectangle { width: 12; height: 12; radius: 6; color: root.role("tertiary", Theme.rose) }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                ActionButton {
                    objectName: "applyThemeSeed"
                    Layout.fillWidth: true
                    text: root.applied ? "Applied" : "Apply theme"
                    selected: true; pending: root.applying
                    enabled: root.status === "ready" && !!root.selectedSeed && !root.applying
                    onClicked: root.applySeed(root.selectedSeed)
                }
                ActionButton {
                    objectName: "automaticThemeSeed"
                    text: root.automatic ? "Automatic ✓" : "Automatic"
                    enabled: root.canAutomatic && !root.applying
                    onClicked: root.applySeed("")
                }
            }
            Text {
                Layout.fillWidth: true
                text: root.applicationError || root.error || (root.customColors ? "Custom spectral colors still override their theme roles." : "Changes shell colors; keeps your wallpaper.")
                color: root.applicationError || root.error ? Theme.warning : Theme.muted
                font.family: Theme.fontText; font.pixelSize: 11; wrapMode: Text.Wrap
            }
        }
    }
}
