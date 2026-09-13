import QtQuick
import Quickshell

Window {
    id: window
    width: 680; height: 760; visible: true; color: "#201d23"
    property var manual: null
    Rectangle { anchors.fill: parent; color: window.color }
    Component.onCompleted: {
        const component = Qt.createComponent(Quickshell.env("MANUAL_SOURCE"));
        if (component.status !== Component.Ready) { console.error("MANUAL_FAILED", component.errorString()); Qt.quit(); return; }
        manual = component.createObject(contentItem, {x: 20, y: 20, width: 640, height: 720,
            currentTab: Number(Quickshell.env("MANUAL_TAB") || "0")});
        if (!manual) { console.error("MANUAL_FAILED"); Qt.quit(); return; }
        capture.start();
    }
    Timer {
        id: capture; interval: 500
        onTriggered: window.contentItem.grabToImage(function(result) {
            console.log(result.saveToFile(Quickshell.env("MANUAL_IMAGE")) ? "MANUAL_RENDERED" : "MANUAL_FAILED");
            Qt.quit();
        })
    }
}
