import QtQuick
import Quickshell
import Quickshell.Widgets
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
    readonly property bool targetScreen: ShellState.ephemerisOutput.length > 0
        ? ShellState.ephemerisOutput === outputName
        : Compositor.focusedOutput.length > 0
            ? Compositor.focusedOutput === outputName
            : Quickshell.screens.length > 0 && modelData === Quickshell.screens[0]
    readonly property int barClearance: (Settings.compact ? 38 : Theme.barHeight)
        + (Settings.barMode === "docked" ? 10 : Settings.barMargin * 2 + 8)
    readonly property int topClearance: Settings.edgeHasIslands(outputName, "top") ? barClearance : 16
    readonly property int bottomClearance: Settings.edgeHasIslands(outputName, "bottom") ? barClearance : 16
    readonly property int leftClearance: Settings.edgeHasIslands(outputName, "left") ? barClearance : 16
    readonly property int rightClearance: Settings.edgeHasIslands(outputName, "right") ? barClearance : 16
    readonly property var widgetLayout: {
        const layout = Registry.getLayout(transition.activeTab, width, height,
            topClearance, bottomClearance, leftClearance, rightClearance,
            Settings.ephemerisStyle);
        if (widgetLoader.status === Loader.Ready && widgetLoader.item
                && widgetLoader.item.preferredSurfaceHeight !== undefined)
            layout.height = Math.min(layout.height,
                Math.max(240, widgetLoader.item.preferredSurfaceHeight));
        return layout;
    }
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

    readonly property rect originRect: {
        const barPos = Settings.barPosition;
        const barThick = Settings.compact ? 34 : Theme.barHeight;
        const barPad = Settings.barMode === "docked" ? 2 : Math.max(4, Settings.barMargin);
        const tab = transition.activeTab;

        let ox = 0, oy = 0, ow = 48, oh = 40;

        if (barPos === "left" || barPos === "right") {
            ox = barPos === "left" ? barPad : (root.width - barThick - barPad);
            ow = barThick;
            oh = tab === "calendar" ? 72 : (tab === "workspaces" ? 80 : 40);
            if (tab === "calendar") {
                oy = Math.round((root.height - oh) / 2);
            } else if (tab === "notifications" || tab === "settings" || tab === "audio" || tab === "network" || tab === "battery") {
                oy = Math.max(0, root.height - barPad - 160);
            } else if (tab === "workspaces") {
                oy = barPad + 60;
            } else {
                oy = barPad + 12;
            }
        } else {
            oy = barPos === "bottom" ? (root.height - barThick - barPad) : barPad;
            oh = barThick;
            ow = tab === "calendar" ? 140 : (tab === "media" ? 160 : (tab === "workspaces" ? 90 : 48));
            if (tab === "calendar") {
                ox = Math.round((root.width - ow) / 2);
            } else if (tab === "notifications" || tab === "settings" || tab === "audio" || tab === "network" || tab === "battery") {
                ox = Math.max(0, root.width - barPad - 200);
            } else if (tab === "workspaces") {
                ox = barPad + 70;
            } else if (tab === "media") {
                ox = barPad + 170;
            } else {
                ox = barPad + 16;
            }
        }
        return Qt.rect(ox, oy, ow, oh);
    }

    InstrumentGeometry {
        id: surfaceGeometry
        origin: root.originRect
        destination: Qt.rect(root.widgetLayout.x, root.widgetLayout.y, root.widgetLayout.width, root.widgetLayout.height)
        progress: transition.contentProgress
        motion: Settings.motion
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Theme.void_.r, Theme.void_.g, Theme.void_.b, ShellState.deepFocus ? 0.45 : 0.18)
        opacity: transition.revealProgress
        MouseArea { anchors.fill: parent; onClicked: root.close() }

        InstrumentBridge {
            anchors.fill: parent
            geometry: surfaceGeometry
            visible: Settings.joinedSurfaces && surfaceGeometry.motion && surfaceGeometry.amount > 0.01 && surfaceGeometry.amount < 0.99 && !root.immersiveWidget
        }

        ClippingRectangle {
            id: deck
            x: surfaceGeometry.x; y: surfaceGeometry.y
            width: surfaceGeometry.width; height: surfaceGeometry.height
            // The geometry expands into the solid instrument backing and rounded mask.
            // Parallax stays open; Resonance and other panels own rounded, clipped containment.
            radius: surfaceGeometry.radius
            color: root.immersiveWidget ? "transparent" : Theme.mantle
            clip: true
            opacity: Settings.motion ? 0.80 + 0.20 * transition.contentProgress : 1
            scale: Settings.motion && Settings.motionStyle !== "rise"
                ? 0.96 + 0.04 * transition.contentProgress : 1

            Item {
                id: fixedContent
                x: root.widgetLayout.x - surfaceGeometry.x
                y: root.widgetLayout.y - surfaceGeometry.y
                width: root.widgetLayout.width
                height: root.widgetLayout.height

                MouseArea { anchors.fill: parent; onClicked: if (root.immersiveWidget) root.close() }

                // Super+Alt anywhere on an open widget opens that widget's own
                // settings, matching the gesture the bar islands answer to.
                // Sits above the widget so it wins the press, and declines
                // every other click so normal interaction is untouched.
                MouseArea {
                    anchors.fill: parent
                    z: 9999
                    acceptedButtons: Qt.LeftButton
                    onPressed: function(mouse) {
                        const hasMeta = Boolean(mouse.modifiers & Qt.MetaModifier);
                        const hasAlt = Boolean(mouse.modifiers & Qt.AltModifier);
                        if (!(hasMeta && hasAlt)) {
                            mouse.accepted = false;
                            return;
                        }
                        mouse.accepted = true;
                        const origin = mapToItem(null, 0, 0);
                        ShellState.openWidgetSettings(transition.activeTab,
                            origin.x, origin.y, width, height);
                    }
                }
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
}
