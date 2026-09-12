import QtQuick
import Quickshell

Window {
    width: 900; height: 700; visible: true
    property var controls: []
    Component.onCompleted: {
        for (const path of JSON.parse(Quickshell.env("CONTROL_SOURCES"))) {
            const component = Qt.createComponent(path);
            if (component.status !== Component.Ready) { console.error("CONTROL_FAILED", component.errorString()); Qt.quit(); return; }
            const control = component.createObject(contentItem, {
                width: 260, label: "A long setting label that must wrap without escaping",
                detail: "Descriptions should remain readable on smaller displays and with translated text."
            });
            if (!control) { console.error("CONTROL_FAILED creation"); Qt.quit(); return; }
            if (control.choices !== undefined)
                control.choices = [{label: "FIRST CHOICE", value: 1}, {label: "SECOND CHOICE", value: 2}, {label: "THIRD CHOICE", value: 3}];
            controls.push(control);
        }
        check.start();
    }
    function bounded(item, root) {
        if (!item.visible) return true;
        if (item.text !== undefined && item.width > 0) {
            const point = item.mapToItem(root, 0, 0);
            if (point.x < -1 || point.y < -1 || point.x + item.width > root.width + 1
                    || point.y + item.height > root.height + 1) return false;
        }
        for (const child of item.children) if (!bounded(child, root)) return false;
        return true;
    }
    Timer {
        id: check; interval: 250
        onTriggered: {
            for (const control of controls) {
                if (control.implicitHeight < 54 || !bounded(control, control)) {
                    console.error("CONTROL_FAILED bounds"); Qt.quit(); return;
                }
            }
            console.log("CONTROL_LAYOUT_OK"); Qt.quit();
        }
    }
}
