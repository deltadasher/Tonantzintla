pragma Singleton

import QtQuick

QtObject {
    id: root

    property bool visible: false
    property string kind: "volume"
    property string label: "VOLUME"
    property int value: 0
    property bool muted: false
    property int serial: 0

    function show(nextKind, nextValue, nextLabel, nextMuted) {
        kind = nextKind || "volume";
        value = Math.max(0, Math.min(150, Math.round(nextValue)));
        label = nextLabel || kind.toUpperCase();
        muted = nextMuted === true;
        visible = true;
        serial++;
        hideTimer.restart();
    }

    property Timer hideTimer: Timer {
        interval: 1450
        onTriggered: root.visible = false
    }
}
