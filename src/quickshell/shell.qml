//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Io
import "modules/aperture"
import "modules/ephemeris"
import "modules/osd"
import "modules/quickactions"
import "modules/transit"
import "modules/umbra"
import "modules/umbra/reveal"
import "services"

ShellRoot {
    id: root
    // Instantiate the idle watcher even when the settings panel is closed.
    readonly property string idleLockStatus: IdleLock.status

    property bool ephemerisResident: ShellState.ephemerisVisible
    property bool umbraPreviewResident: Umbra.previewActive
    property bool umbraRevealResident: false
    readonly property bool sessionIngress: Quickshell.env("TONANTZINTLA_SESSION_INGRESS") === "1"

    Connections {
        target: Settings
        function onBarPositionChanged() {
            // Edge changes are global. Drop stale per-output placements so a
            // widget left on the old edge cannot survive on one monitor.
            Settings.barOutputOverrides = "";
            Settings.barIslandPlacements = "";
        }
    }
    readonly property var focusedScreens: {
        const screens = Quickshell.screens;
        if (screens.length === 0)
            return [];
        if (Compositor.focusedOutput.length === 0)
            return [screens[0]];
        for (let index = 0; index < screens.length; index++) {
            if (screens[index].name === Compositor.focusedOutput)
                return [screens[index]];
        }
        return [screens[0]];
    }

    // Ephemeris remembers the output that launched it. Commands from outside
    // a bar fall back to the compositor focus.
    readonly property var ephemerisScreens: {
        const screens = Quickshell.screens;
        if (screens.length === 0)
            return [];
        const requested = ShellState.ephemerisOutput || Compositor.focusedOutput;
        if (requested) {
            for (let index = 0; index < screens.length; index++) {
                if (screens[index].name === requested)
                    return [screens[index]];
            }
        }
        return [screens[0]];
    }
    Connections {
        target: ShellState

        function onEphemerisVisibleChanged() {
            if (ShellState.ephemerisVisible) {
                ephemerisUnload.stop();
                root.ephemerisResident = true;
            } else {
                ephemerisUnload.restart();
            }
        }

        function onUmbraRevealSerialChanged() {
            root.umbraRevealResident = true;
            umbraRevealUnload.restart();
        }
    }

    Connections {
        target: Umbra

        function onPreviewActiveChanged() {
            if (Umbra.previewActive) {
                umbraPreviewUnload.stop();
                root.umbraPreviewResident = true;
            } else {
                umbraPreviewUnload.restart();
            }
        }
    }

    Timer {
        id: ephemerisUnload
        interval: Settings.motion ? 220 : 130
        onTriggered: root.ephemerisResident = false
    }

    Component.onCompleted: {
        if (sessionIngress) {
            root.umbraRevealResident = true;
            Qt.callLater(ShellState.startUmbraReveal);
        }
    }

    Timer {
        id: umbraPreviewUnload
        interval: 80
        onTriggered: root.umbraPreviewResident = false
    }

    Timer {
        id: umbraRevealUnload
        interval: Settings.motion && Settings.umbraMotion ? 2500 : 100
        onTriggered: root.umbraRevealResident = false
    }

    IpcHandler {
        target: "ephemeris"

        function close(): void {
            ShellState.closeEphemeris();
        }

        function open(tab: string): void {
            ShellState.openEphemeris(tab);
        }

        function openSection(tab: string, section: string): void {
            if (section && section.length > 0)
                ShellState.settingsSection = section;
            ShellState.openEphemeris(tab);
        }

        function toggle(tab: string): void {
            ShellState.toggleEphemeris(tab);
        }
    }

    IpcHandler {
        target: "transit"

        function preview(summary: string, body: string): void {
            Notifications.preview(summary, body);
        }
    }

    IpcHandler {
        target: "quickactions"

        function open(tab: string): void {
            ShellState.openQuickActions(tab);
        }

        function toggle(tab: string): void {
            ShellState.toggleQuickActions(tab);
        }

        function hide(): void {
            ShellState.hideQuickActions();
        }
    }

    IpcHandler {
        target: "umbra"

        function lock(): void {
            ShellState.closeEphemeris();
            ShellState.hideQuickActions();
            Umbra.launchLock();
        }

        function preview(): void {
            ShellState.closeEphemeris();
            ShellState.hideQuickActions();
            Umbra.preview();
        }

        function closePreview(): void {
            Umbra.closePreview();
        }

        function reveal(): void {
            ShellState.startUmbraReveal();
        }
    }

    IpcHandler {
        target: "aperture"

        function edit(): void {
            ShellState.enterBarEditMode();
        }

        function closeEdit(): void {
            ShellState.exitBarEditMode();
        }

        function toggleEdit(): void {
            ShellState.toggleBarEditMode();
        }

        function openIsland(islandId: string): void {
            ShellState.openIslandSettings(islandId, null, 960, 0, 100, 48);
        }

        function closeIsland(): void {
            ShellState.closeIslandSettings();
        }

        function startDrag(islandId: string, zone: string): void {
            ShellState.startIslandDrag(islandId, null, zone);
        }

        function updateDrag(gx: real, gy: real): void {
            ShellState.updateIslandDrag(gx, gy, 1920, 1080, false);
        }

        function finishDrag(): void {
            ShellState.finishIslandDrag(false);
        }
    }

    Variants {
        model: Quickshell.screens
        ApertureOutput {}
    }

    Variants {
        model: ShellState.islandSettingsVisible ? root.focusedScreens : []
        IslandQuickSettings {}
    }

    Variants {
        model: ShellState.widgetSettingsVisible ? root.focusedScreens : []
        WidgetQuickSettings {}
    }

    Variants {
        model: ShellState.barEditMode ? root.focusedScreens : []
        BarEditStudio {}
    }

    Variants {
        model: root.ephemerisResident ? root.ephemerisScreens : []
        EphemerisSurface {}
    }

    Variants {
        model: Osd.visible ? root.focusedScreens : []
        OsdPopup {}
    }

    Variants {
        model: root.umbraPreviewResident ? root.focusedScreens : []
        UmbraPreview {}
    }

    Variants {
        model: root.umbraRevealResident ? Quickshell.screens : []
        UmbraReveal {}
    }

    NotificationPopups {}
}
