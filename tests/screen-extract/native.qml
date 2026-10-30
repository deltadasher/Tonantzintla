import QtQuick
import Quickshell
import "."
import "services"
import "modules/ephemeris/widgets/desktop"

Window {
    id: root
    width: 1080; height: 650; visible: true; color: Theme.void_
    property int failures: 0
    property int phase: 0
    property int ticks: 0
    property string expected: "雪猫\nhttps://example.com/?a=1&b=2"
    property string mode: Quickshell.env("EXTRACT_TEST_MODE")
    property bool missing: mode === "missing"
    function check(ok, message) {
        if (!ok) { failures++; console.error("EXTRACT_FAIL", message); }
    }
    function find(item, name) {
        if (item.objectName === name) return item;
        for (let child of item.children || []) { const found = find(child, name); if (found) return found; }
        return null;
    }
    function contained(item, name) {
        check(!!item, name + " exists");
        if (!item) return;
        const point = item.mapToItem(widget, 0, 0);
        check(item.width > 0 && item.height > 0, name + " positive size");
        check(point.x >= -1 && point.y >= -1 && point.x + item.width <= widget.width + 1
              && point.y + item.height <= widget.height + 1, name + " fits capture widget");
    }
    CaptureWidget { id: widget; anchors.fill: parent; anchors.margins: 18 }
    Timer {
        interval: 100; running: true; repeat: true
        onTriggered: {
            root.ticks++;
            if (root.ticks > 100) { root.check(false, "scenario timed out at phase " + root.phase); done(); return; }
            if (root.phase === 0 && ScreenExtract.capabilities.state) {
                if (root.missing) {
                    root.check(!ScreenExtract.capabilities.qrAvailable, "missing QR dependency is unavailable");
                    root.check(!root.find(widget, "readQrButton").enabled, "missing QR button disabled");
                } else {
                    root.check(ScreenExtract.capabilities.qrAvailable, "actual QR decoder available");
                }
                root.check(ScreenExtract.start("qr", Quickshell.env("EXTRACT_TEST_IMAGE")), "start accepted");
                root.check(!ScreenExtract.start("qr", Quickshell.env("EXTRACT_TEST_IMAGE")), "busy start rejected");
                if (root.mode === "reader-fail") ScreenExtract._command = ["/nonexistent-screen-extract-reader"];
                if (root.mode === "probe-fail") {
                    ScreenExtract.cancel();
                    ScreenExtract.capabilities = ({});
                    ScreenExtract.probe.command = ["/nonexistent-screen-extract-probe"];
                    ScreenExtract.refresh();
                    root.phase = 7; root.ticks = 0;
                } else { root.phase = 1; root.ticks = 0; }
            } else if (root.mode === "reader-fail" && root.phase === 1 && root.ticks > 10) {
                root.check(!ScreenExtract.busy && ScreenExtract.state === "error", "reader failed start settles promptly");
                done(); return;
            } else if (root.phase === 7 && root.ticks > 10) {
                root.check(ScreenExtract.capabilities.state === "error", "probe failed start settles promptly");
                done(); return;
            } else if (root.phase === 1 && root.mode !== "reader-fail" && !ScreenExtract.busy) {
                if (root.missing) {
                    root.check(ScreenExtract.state === "error", "missing decoder is error");
                    root.check(ScreenExtract.text === "", "missing decoder exposes no stale text");
                    root.check(ScreenExtract.message.indexOf("zbarimg") >= 0, "missing decoder explained");
                    done(); return;
                }
                root.check(ScreenExtract.state === "ready", "real QR extraction ready");
                root.check(ScreenExtract.text === root.expected, "Unicode and multiline QR preserved");
                root.check(ScreenExtract.values.length === 1 && ScreenExtract.values[0] === root.expected, "QR value list preserved");
                root.check(ScreenExtract.message.indexOf("Could not") < 0, "ready has no failure message");
                root.check(!ScreenExtract.copied && !ScreenExtract.copyBusy, "extraction does not auto-copy");
                root.check(root.find(widget, "extractedText").text === root.expected, "real pane displays extraction");
                root.contained(root.find(widget, "readTextButton"), "text action");
                root.contained(root.find(widget, "readQrButton"), "QR action");
                root.contained(root.find(widget, "copyExtractButton"), "copy action");
                root.contained(root.find(widget, "extractedText"), "text output");
                root.phase = 2;
                root.contentItem.grabToImage(function(image) {
                    root.check(image.saveToFile(Quickshell.env("EXTRACT_TEST_CAPTURE")), "screenshot saved");
                    if (root.mode === "copy-fail") ScreenExtract.copier.command = ["/nonexistent-screen-extract-copy"];
                    ScreenExtract.copy();
                    if (root.mode !== "copy-fail") root.check(!ScreenExtract.start("qr", Quickshell.env("EXTRACT_TEST_IMAGE")), "read blocked while explicit copy is pending");
                    root.phase = 3; root.ticks = 0;
                });
            } else if (root.mode === "copy-fail" && root.phase === 3 && root.ticks > 10) {
                root.check(!ScreenExtract.copyBusy && !ScreenExtract.copied, "copier failed start clears pending state");
                root.check(ScreenExtract.message.indexOf("copy") >= 0, "copy failure explained");
                done(); return;
            } else if (root.phase === 3 && root.mode !== "copy-fail" && !ScreenExtract.copyBusy) {
                root.check(ScreenExtract.copied, "explicit copy succeeds");
                ScreenExtract.clear();
                root.check(ScreenExtract.state === "idle" && ScreenExtract.text === "" && ScreenExtract.values.length === 0 && !ScreenExtract.copied, "clear forgets content");
                ScreenExtract.start("qr");
                root.phase = 4;
                root.ticks = 0;
            } else if (root.phase === 4 && root.ticks >= 20) {
                root.check(ScreenExtract.busy, "selection remains active before cancel");
                ScreenExtract.cancel();
                root.phase = 5;
            } else if (root.phase === 5 && !ScreenExtract.busy) {
                root.check(ScreenExtract.state === "cancelled", "running selector cancelled");
                root.check(ScreenExtract.text === "" && ScreenExtract.values.length === 0, "cancel leaves no stale contents");
                root.check(!ScreenExtract.reader.running, "cancel reaps reader");
                done();
            }
        }
        function done() { console.log("EXTRACT_COMPLETE", root.failures); stop(); Qt.quit(); }
    }
}
