import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import "../.."
import "../../services"
import "../../components"
import "../../components/ApertureMetrics.js" as ApertureMetrics
import "EphemerisRegistry.js" as Registry

PanelWindow {
    id: root
    required property var modelData
    screen: modelData
    readonly property string activeInstrument: transition.activeTab.split(":")[0]
    readonly property bool compactInstrument: transition.activeTab.indexOf(":quick") >= 0
    readonly property string outputName: modelData.name
    readonly property bool targetScreen: ShellState.ephemerisOutput.length > 0
        ? ShellState.ephemerisOutput === outputName
        : Compositor.focusedOutput.length > 0
            ? Compositor.focusedOutput === outputName
            : Quickshell.screens.length > 0 && modelData === Quickshell.screens[0]
    function clearance(edge) {
        return ApertureMetrics.clearance(edge, Settings.edgeHasIslands(outputName, edge),
            Settings.compact, Settings.barHeightProfile, Theme.barHeight,
            Settings.barMode, Settings.barMargin);
    }
    readonly property real topClearance: clearance("top")
    readonly property real bottomClearance: clearance("bottom")
    readonly property real leftClearance: clearance("left")
    readonly property real rightClearance: clearance("right")
    readonly property var safeArea: Registry.safeArea(width, height, topClearance,
        bottomClearance, leftClearance, rightClearance)
    property bool displayedAnchorValid: false
    property real displayedAnchorX: 0
    property real displayedAnchorY: 0
    property real displayedAnchorWidth: 0
    property real displayedAnchorHeight: 0
    property string displayedAnchorEdge: "top"
    // The source, backing, rounded mask, and input lifetime share one transition.
    readonly property bool sourcePositioned: displayedAnchorValid
    readonly property bool anchoredInstrument: sourcePositioned && !root.immersiveWidget
    readonly property string anchorEdge: sourcePositioned
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
        const layout = Registry.getLayout(root.activeInstrument, width, height,
            topClearance, bottomClearance, leftClearance, rightClearance,
            Settings.ephemerisStyle);
        if (widgetLoader.status === Loader.Ready && widgetLoader.item
                && widgetLoader.item.preferredSurfaceHeight !== undefined)
            layout.height = Math.min(layout.height,
                Math.max(240, widgetLoader.item.preferredSurfaceHeight));

        if (widgetLoader.status === Loader.Ready && widgetLoader.item
                && widgetLoader.item.preferredSurfaceWidth !== undefined)
            layout.width = Math.min(layout.width, widgetLoader.item.preferredSurfaceWidth);
        if (sourcePositioned && layout.placement !== "horizon") {
            Registry.attachLayout(layout, {
                x: displayedAnchorX,
                y: displayedAnchorY,
                width: displayedAnchorWidth,
                height: displayedAnchorHeight
            }, anchorEdge, width, height, topClearance, bottomClearance,
                leftClearance, rightClearance, 8);
        }
        return layout;
    }
    readonly property color moduleTone: Theme.moduleAccent(root.activeInstrument)
    readonly property bool immersiveWidget: root.activeInstrument === "walls"
    // Ephemeris is a reading surface. It remains opaque even when Aperture is
    // configured as glass so wallpaper detail cannot compete with its content.
    readonly property real instrumentSurfaceOpacity: 1.0
    // Colour stays opaque inside the Canvas. The aperture-derived alpha is
    // applied once to the complete union, avoiding darker overlap at the lip.
    readonly property color instrumentColor: Theme.void_
    readonly property bool softwareRenderer: safeViewport.GraphicsInfo.api === GraphicsInfo.Software
    readonly property bool gravityRequested: Settings.panelMaterial === "gravity"
        && !root.immersiveWidget && Quickshell.env("TONANTZINTLA_DISABLE_GRAVITY") !== "1"
    readonly property bool gravityReady: gravityBacking.status === Loader.Ready
        && gravityBacking.item && gravityBacking.item.usable
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
        requestedTab: Registry.normalize(ShellState.ephemerisTab) + (ShellState.quickInstrument ? ":quick" : "")
        motionEnabled: Theme.motionScale > 0
        enterDuration: Theme.surfaceEnterDuration
        exitDuration: Theme.surfaceExitDuration
        effectDuration: Theme.effectDuration
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
        const fitted = Registry.fitRect(rawOriginRect, safeArea);
        return Qt.rect(fitted.x, fitted.y, fitted.width, fitted.height);
    }
    readonly property rect rawOriginRect: {
        if (root.anchoredInstrument)
            return Qt.rect(root.displayedAnchorX, root.displayedAnchorY,
                root.displayedAnchorWidth, root.displayedAnchorHeight);

        // Satellite panels do not inflate out of their Aperture button. They
        // begin at full size just ten pixels toward the bar and float into the
        // nearby resting position while their contents reveal.
        if (root.sourcePositioned) {
            const layout = root.widgetLayout;
            let dx = 0, dy = 0;
            if (root.anchorEdge === "top") dy = -10;
            else if (root.anchorEdge === "bottom") dy = 10;
            else if (root.anchorEdge === "left") dx = -10;
            else if (root.anchorEdge === "right") dx = 10;
            return Qt.rect(layout.x + dx, layout.y + dy,
                layout.width, layout.height);
        }

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

    property rect displayedDestination: Qt.rect(root.widgetLayout.x, root.widgetLayout.y, root.widgetLayout.width, root.widgetLayout.height)
    Behavior on displayedDestination { PropertyAnimation { duration: transition.mounted && Theme.motionScale > 0 ? Theme.surfaceEnterDuration : 0; easing.type: Easing.OutCubic } }

    InstrumentGeometry {
        id: surfaceGeometry
        origin: root.originRect
        destination: root.displayedDestination
        progress: transition.revealProgress
        motion: Theme.motionScale > 0
    }

    // Both painting and pointer input stop at the reserved Aperture boundary.
    // Clipping updates immediately if bar settings change during an animation.
    mask: Region { item: safeViewport }
    Item {
        id: safeViewport
        x: root.safeArea.x; y: root.safeArea.y
        width: root.safeArea.width; height: root.safeArea.height
        clip: true
        Item {
            x: -safeViewport.x; y: -safeViewport.y
            width: root.width; height: root.height
            Rectangle {
                anchors.fill: parent
                // Source-anchored instruments leave the desktop undimmed; all
                // other scrims remain inside the same safe area as their panel.
                color: root.anchoredInstrument ? "transparent"
                    : Qt.rgba(Theme.void_.r, Theme.void_.g, Theme.void_.b,
                        ShellState.deepFocus ? 0.45 : 0.18)
                opacity: transition.revealProgress
                MouseArea { anchors.fill: parent; onClicked: root.close() }

                Loader {
                    id: blobBacking
                    anchors.fill: parent
                    active: root.blobExperiment && !root.immersiveWidget && !root.gravityReady
                    source: active ? Qt.resolvedUrl("../../components/ExperimentalBlobBacking.qml") : ""
                    onLoaded: {
                        item.geometry = surfaceGeometry;
                        item.origin = root.originRect;
                        item.anchored = root.anchoredInstrument;
                    }
                }

                Loader {
                    id: gravityBacking
                    active: root.gravityRequested && transition.mounted && root.targetScreen
                    sourceComponent: GravityMaterial {
                        geometry: surfaceGeometry
                        reveal: transition.revealProgress
                        activity: Theme.motionScale > 0
                            ? Math.max(Math.sin(Math.PI * transition.revealProgress),
                                (1 - transition.contentProgress) * 0.7) : 0
                        primary: root.moduleTone
                        secondary: Theme.moduleSecondary(root.activeInstrument)
                        backing: root.instrumentColor
                    }
                }

                InstrumentBridge {
                    anchors.fill: parent
                    geometry: surfaceGeometry
                    edge: root.anchorEdge
                    attached: root.anchoredInstrument
                    fillColor: root.instrumentColor
                    visible: !root.immersiveWidget && !root.gravityReady
                        && (!root.blobExperiment || blobBacking.status === Loader.Error)
                        && transition.revealProgress > 0.01
                    opacity: root.instrumentSurfaceOpacity
                }

                Item {
                    id: softwareDeck
                    x: surfaceGeometry.x; y: surfaceGeometry.y
                    width: surfaceGeometry.width; height: surfaceGeometry.height
                    visible: root.softwareRenderer
                    clip: true
                    opacity: deck.opacity
                    scale: deck.scale
                }

                ClippingRectangle {
                    id: deck
                    visible: !root.softwareRenderer
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
                        // Quickshell's rounded mask itself needs a shader. Keep
                        // controls usable with rectangular clipping in software.
                        parent: root.softwareRenderer ? softwareDeck : deck.contentItem
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
                                ShellState.openWidgetSettings(root.activeInstrument,
                                    origin.x, origin.y, width, height);
                            }
                        }
                        EphemerisAtmosphere {
                            anchors.fill: parent
                            visible: !root.immersiveWidget && !root.gravityReady
                            module: root.activeInstrument
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
                                source: root.compactInstrument ? Qt.resolvedUrl("widgets/catalog/QuickInstrument.qml") : Qt.resolvedUrl(Registry.sourceFor(root.activeInstrument))
                                onLoaded: if (item && item.instrument !== undefined) item.instrument = root.activeInstrument
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
                                    widgetLoader.source = Qt.binding(function() { return root.compactInstrument ? Qt.resolvedUrl("widgets/catalog/QuickInstrument.qml") : Qt.resolvedUrl(Registry.sourceFor(root.activeInstrument)); });
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
