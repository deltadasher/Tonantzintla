import QtQuick
import QtTest
import "../../src/quickshell/components"
import "../../src/quickshell/modules/ephemeris/EphemerisRegistry.js" as Registry
import "../../src/quickshell/services/MediaMath.js" as MediaMath

TestCase {
    id: test
    name: "SurfaceTransition"
    when: windowShown
    width: 640; height: 420
    SurfaceTransition { id: controller }
    InstrumentGeometry { id: geometry }
    function test_media_unknown_duration_never_seeks_to_zero() {
        compare(MediaMath.relativeSeek(0, 42, -10), null);
        compare(MediaMath.absoluteSeek(0, 0.5), null);
        compare(MediaMath.relativeSeek(120, 42, -10), 32);
        compare(MediaMath.relativeSeek(120, 118, 10), 120);
        compare(MediaMath.absoluteSeek(120, NaN), null);
        compare(MediaMath.duration(Infinity), 0);
    }
    function test_geometry_shares_clipping_bounds() {
        geometry.origin = Qt.rect(24, 8, 48, 40);
        geometry.destination = Qt.rect(16, 80, 900, 600);
        geometry.motion = true;
        for (const progress of [-1, 0, 0.25, 0.5, 0.75, 1, 2]) {
            geometry.progress = progress;
            verify(geometry.radius <= geometry.width / 2);
            verify(geometry.radius <= geometry.height / 2);
            verify(geometry.width >= 48 && geometry.width <= 900);
        }
        geometry.motion = false;
        geometry.progress = 0;
        compare(geometry.width, 900);
        compare(geometry.radius, 26);
    }
    SignalSpy { id: deployment; target: controller; signalName: "deploying" }
    function init() {
        controller.requestedVisible = false;
        tryCompare(controller, "mounted", false);
        controller.requestedTab = "apps";
        controller.contentReady = true;
        controller.motionEnabled = true;
        deployment.clear();
    }
    function test_open_waits_for_content() {
        controller.contentReady = false;
        controller.requestedVisible = true;
        tryCompare(controller, "phase", "loading");
        compare(controller.contentProgress, 0);
        compare(controller.interactive, false);
        controller.contentReady = true;
        tryCompare(controller, "phase", "open");
        compare(controller.contentProgress, 1);
        compare(deployment.count, 1);
    }
    function test_switch_keeps_old_content_until_hidden() {
        controller.requestedVisible = true;
        tryCompare(controller, "phase", "open");
        controller.requestedTab = "walls";
        compare(controller.activeTab, "apps");
        compare(controller.interactive, false);
        tryCompare(controller, "activeTab", "walls");
        verify(controller.contentProgress < 0.05);
        tryCompare(controller, "phase", "open");
    }
    function test_rapid_switches_use_latest_request() {
        controller.requestedVisible = true;
        tryCompare(controller, "phase", "open");
        controller.requestedTab = "calendar";
        wait(20);
        controller.requestedTab = "media";
        wait(20);
        controller.requestedTab = "walls";
        tryCompare(controller, "phase", "open");
        compare(controller.activeTab, "walls");
        compare(deployment.count, 2);
    }
    function test_close_cancels_switch_and_reopen() {
        controller.requestedVisible = true;
        tryCompare(controller, "phase", "open");
        controller.requestedTab = "calendar";
        wait(30);
        controller.requestedVisible = false;
        wait(35);
        controller.requestedTab = "audio";
        controller.requestedVisible = true;
        tryCompare(controller, "phase", "open");
        compare(controller.activeTab, "audio");
        wait(250);
        compare(controller.mounted, true);
        controller.requestedVisible = false;
        tryCompare(controller, "phase", "closed");
        compare(controller.mounted, false);
    }
    function test_reduced_motion_still_settles() {
        controller.motionEnabled = false;
        controller.requestedVisible = true;
        tryCompare(controller, "phase", "open");
        controller.requestedTab = "settings";
        tryCompare(controller, "activeTab", "settings");
        tryCompare(controller, "phase", "open");
        compare(controller.interactive, true);
    }
    function test_registry_fits_small_and_large_displays() {
        for (const size of [[320, 240], [800, 600], [1920, 1080], [3840, 2160]]) {
            for (const widget of Registry.widgets()) {
                const layout = Registry.getLayout(widget.id, size[0], size[1], 72);
                verify(layout.x >= 0 && layout.y >= 0);
                verify(layout.width > 0 && layout.height > 0);
                verify(layout.x + layout.width <= size[0]);
                verify(layout.y + layout.height <= size[1]);
            }
        }
        compare(Registry.normalize("unknown"), "apps");
    }
}
