import QtQuick
import Quickshell

// Compile the actual widget graph without constructing widgets or services.
// Run with qs, not qmltestrunner: Quickshell types require its application.
QtObject {
    property Timer check: Timer {
        interval: 1
        running: true
        onTriggered: {
            let failures = 0;
            const sources = JSON.parse(Quickshell.env("TONANTZINTLA_TEST_SOURCES") || "[]");
            if (sources.length === 0) failures++;
            for (const source of sources) {
                const component = Qt.createComponent("file://" + source);
                if (component.status !== Component.Ready) {
                    console.error("SURFACE FAIL", source, component.errorString());
                    failures++;
                }
                component.destroy();
            }
            console.log("SURFACE COMPILE COMPLETE", failures, "failures");
            Qt.quit();
        }
    }
}
