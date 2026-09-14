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
    property bool displayedAnchorValid: false
    property real displayedAnchorX: 0
    property real displayedAnchorY: 0
    property real displayedAnchorWidth: 0
    property real displayedAnchorHeight: 0
    property string displayedAnchorEdge: "top"
    readonly property bool anchoredInstrument: displayedAnchorValid
    readonly property string anchorEdge: anchoredInstrument
        ? displayedAnchorEdge : Settings.getEffectiveBarPosition(outputName)

    function captureRequestedAnchor() {
        displayedAnchorValid = ShellState.ephemerisAnchorValid
            && (ShellState.ephemerisOutput.length === 0
                || ShellState.ephemerisOutput === outputName);
        displayedAnchorX = ShellState.ephemerisAnchorX;
        displayedAnchorY = ShellState.ephemerisAnchorY;
        displayedAnchorWidth = ShellState.ephemerisAnchorWidth;
        displayedAnchorHeight = ShellState.ephemerisAnchorHeight;
        displayedAnchorEdge = ShellState.ephemerisAnchorEdge;
    }
    Component.onCompleted: captureRequestedAnchor()
    readonly property var widgetLayout: {
        const layout = Registry.getLayout(transition.activeTab, width, height,
            topClearance, bottomClearance, leftClearance, rightClearance,
            Settings.ephemerisStyle);
        if (widgetLoader.status === Loader.Ready && widgetLoader.item
                && widgetLoader.item.preferredSurfaceHeight !== undefined)
            layout.height = Math.min(layout.height,
                Math.max(240, widgetLoader.item.preferredSurfaceHeight));

        if (anchoredInstrument && layout.placement !== "horizon") {
            Registry.attachLayout(layout, {
                x: displayedAnchorX,
                y: displayedAnchorY,
                width: displayedAnchorWidth,
                height: displayedAnchorHeight
            }, anchorEdge, width, height, topClearance, bottomClearance,
                leftClearance, rightClearance);
        }
        return layout;
    }
    readonly property color moduleTone: Theme.moduleAccent(transition.activeTab)
    readonly property bool immersiveWidget: transition.activeTab === "walls"
    // Ephemeris is a reading surface. It remains opaque even when Aperture is
    // configured as glass so wallpaper detail cannot compete with its content.
    readonly property real instrumentSurfaceOpacity: 1.0
    // Colour stays opaque inside the Canvas. The aperture-derived alpha is
    // applied once to the complete union, avoiding darker overlap at the lip.
    readonly property color instrumentColor: Theme.void_
    readonly property bool blobExperiment: Quickshell.env("TONANTZINTLA_BLOB_EXPERIMENT") === "1"

    visible: transition.mounted && targetScreen
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    WlrLayershell.layer: root.anchoredInstrument ? WlrLayer.Top : WlrLayer.Overlay
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

    Connections {
        target: transition
        function onMountedChanged() {
            if (transition.mounted)
                root.captureRequestedAnchor();
        }
        function onActiveTabChanged() { root.captureRequestedAnchor(); }
    }

    readonly property rect originRect: {
        if (root.anchoredInstrument)
            return Qt.rect(root.displayedAnchorX, root.displayedAnchorY,
                root.displayedAnchorWidth, root.displayedAnchorHeight);

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
        // Attached instruments and their Aperture source must composite over
        // the same pixels or equal alpha values still appear mismatched.
        color: root.anchoredInstrument ? "transparent"
            : Qt.rgba(Theme.void_.r, Theme.void_.g, Theme.void_.b,
                ShellState.deepFocus ? 0.45 : 0.18)
        opacity: transition.revealProgress
        MouseArea { anchors.fill: parent; onClicked: root.close() }

        Loader {
            id: blobBacking
            anchors.fill: parent
            active: root.blobExperiment && !root.immersiveWidget
            source: active ? Qt.resolvedUrl("../../components/ExperimentalBlobBacking.qml") : ""
            onLoaded: {
                item.geometry = surfaceGeometry;
                item.origin = root.originRect;
                item.anchored = root.anchoredInstrument;
            }
        }

        InstrumentBridge {
            anchors.fill: parent
            geometry: surfaceGeometry
            edge: root.anchorEdge
            attached: root.anchoredInstrument
            fillColor: root.instrumentColor
            visible: !root.immersiveWidget
                && (!root.blobExperiment || blobBacking.status === Loader.Error)
                && transition.revealProgress > 0.01
            opacity: root.instrumentSurfaceOpacity
        }

        ClippingRectangle {
            id: deck
            x: surfaceGeometry.x; y: surfaceGeometry.y
            width: surfaceGeometry.width; height: surfaceGeometry.height
            // The geometry expands into the solid instrument backing and rounded mask.
            // Parallax stays open; Resonance and other panels own rounded, clipped containment.
            radius: surfaceGeometry.radius
            color: "transparent"
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
