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

    property bool ephemerisResident: ShellState.ephemerisVisible
    property bool quickActionsResident: ShellState.quickActionsVisible
    property bool umbraPreviewResident: Umbra.previewActive
    property bool umbraRevealResident: false
    readonly property bool sessionIngress: Quickshell.env("TONANTZINTLA_SESSION_INGRESS") === "1"
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

        function onQuickActionsVisibleChanged() {
            if (ShellState.quickActionsVisible) {
                quickActionsUnload.stop();
                root.quickActionsResident = true;
            } else {
                quickActionsUnload.restart();
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
        interval: Settings.motion ? 220 : 1
        onTriggered: root.ephemerisResident = false
    }

    Component.onCompleted: {
        if (sessionIngress) {
            root.umbraRevealResident = true;
            Qt.callLater(ShellState.startUmbraReveal);
        }
    }

    Timer {
        id: quickActionsUnload
        interval: Settings.motion ? 210 : 1
        onTriggered: root.quickActionsResident = false
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

    Variants {
        model: Quickshell.screens
        ApertureBar {}
    }

    Variants {
        model: root.ephemerisResident ? root.focusedScreens : []
        EphemerisSurface {}
    }

    Variants {
        model: Osd.visible ? root.focusedScreens : []
        OsdPopup {}
    }

    Variants {
        model: root.quickActionsResident ? root.focusedScreens : []
        QuickActionsRail {}
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
