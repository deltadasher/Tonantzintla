import QtQuick
import Quickshell
import Quickshell.Wayland
import "../.."
import "../../services"
import "../../components"
import "EphemerisRegistry.js" as Registry

PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    readonly property string outputName: modelData.name
    readonly property bool targetScreen: Compositor.focusedOutput.length > 0
        ? Compositor.focusedOutput === outputName
        : Quickshell.screens.length > 0 && modelData === Quickshell.screens[0]
    readonly property int topClearance: (Settings.compact ? 38 : Theme.barHeight)
        + (Settings.barMode === "docked" ? 10 : Settings.barMargin * 2 + 8)
    readonly property var widgetLayout: Registry.getLayout(transition.activeTab, width, height, topClearance)
    readonly property color moduleTone: Theme.moduleAccent(transition.activeTab)
    readonly property bool immersiveWidget: transition.activeTab === "walls"

    visible: transition.mounted && targetScreen
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "tonantzintla-ephemeris-host"
    anchors { top: true; right: true; bottom: true; left: true }

    function close() { ShellState.closeEphemeris(); }
    function focusWidget() {
        if (!transition.interactive) return;
        if (widgetLoader.item && widgetLoader.item.focusPrimary) widgetLoader.item.focusPrimary();
        else keyCatcher.forceActiveFocus();
    }

    SurfaceTransition {
        id: transition
        requestedVisible: ShellState.ephemerisVisible && root.targetScreen
        requestedTab: Registry.normalize(ShellState.ephemerisTab)
        motionEnabled: Settings.motion
        contentReady: widgetLoader.status === Loader.Ready || widgetLoader.status === Loader.Error
        onDeploying: {
            if (widgetLoader.item && widgetLoader.item.beginDeployment) widgetLoader.item.beginDeployment();
        }
        onSettled: root.focusWidget()
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Theme.void_.r, Theme.void_.g, Theme.void_.b, ShellState.deepFocus ? 0.45 : 0.18)
        opacity: transition.revealProgress
        MouseArea { anchors.fill: parent; onClicked: root.close() }

        Loader {
            anchors.fill: parent
            active: transition.mounted && !root.immersiveWidget
                && transition.activeTab !== "media"
            source: active ? "TonantzintlaMorphBackdrop.qml" : ""

            property var layout: root.widgetLayout
            property real reveal: Settings.motion ? transition.contentProgress : 1
            property color tone: root.moduleTone
            property string tab: transition.activeTab
        }

        Rectangle {
            id: deck
            x: root.widgetLayout.x; y: root.widgetLayout.y
            width: root.widgetLayout.width; height: root.widgetLayout.height
            // The morph layer expands into the solid instrument backing.
            // Parallax stays open; Resonance owns its rounded, clipped backing.
            radius: 26
            color: "transparent"
            clip: true
            // Layout changes happen only after the old contents have left.
            // The layer-shell host never resizes during these transitions.
            opacity: Settings.motion ? 0.80 + 0.20 * transition.contentProgress : 1
            scale: Settings.motion && Settings.motionStyle !== "rise"
                ? 0.96 + 0.04 * transition.contentProgress : 1

            MouseArea { anchors.fill: parent; onClicked: if (root.immersiveWidget) root.close() }
            EphemerisAtmosphere {
                anchors.fill: parent
                visible: !root.immersiveWidget
                module: transition.activeTab
                presentation: transition.contentProgress
            }
            WabiSabiBlackHole {
                anchors.centerIn: parent
                width: Math.min(150, parent.width * 0.3); height: width * 0.7
                visible: Settings.motion && transition.phase !== "open" && transition.phase !== "closing"
                opacity: 0.35 * (1 - transition.contentProgress)
                diskColor: root.moduleTone; horizonColor: Theme.mantle
            }
            Item {
                id: keyCatcher
                anchors.fill: parent
                focus: true
                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Escape) { root.close(); event.accepted = true; }
                }
                Loader {
                    id: widgetLoader
                    anchors.fill: parent
                    anchors.margins: root.immersiveWidget ? 8 : 20
                    active: transition.mounted
                    asynchronous: true
                    focus: true
                    enabled: transition.interactive
                    visible: status === Loader.Ready
                    opacity: transition.contentProgress
                    transform: Translate { y: Settings.motion && Settings.motionStyle === "rise" ? (1 - transition.contentProgress) * 18 : 0 }
                    source: Qt.resolvedUrl(Registry.sourceFor(transition.activeTab))
                }
                StatusMessage {
                    anchors.centerIn: parent
                    width: Math.min(parent.width - 40, 400)
                    visible: widgetLoader.status === Loader.Error
                    title: "This instrument couldn’t open"
                    detail: root.widgetLayout.title + ". Try again, or use Escape to return to your desktop."
                    actionText: "Try again"
                    onActivated: {
                        widgetLoader.source = "";
                        widgetLoader.source = Qt.binding(function() { return Qt.resolvedUrl(Registry.sourceFor(transition.activeTab)); });
                    }
                }
            }
        }
    }
}
