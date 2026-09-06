import QtQuick
import "../../../.."

Item {
    id: root
    property var solar: null
    property string location: ""
    property string unavailableText: "SET A WEATHER LOCATION"
    property real epoch: Date.now() / 1000
    signal configureRequested()
    readonly property bool available: solar !== null && solar.start > 0 && solar.end > solar.start
    readonly property bool isToday: available && epoch >= solar.start && epoch < solar.end
    readonly property real progress: isToday ? fraction(epoch) : -1
    readonly property var events: available ? [
        {key: "dawn", label: "DAWN"}, {key: "sunrise", label: "SUNRISE"},
        {key: "noon", label: "SOLAR NOON"}, {key: "sunset", label: "SUNSET"},
        {key: "dusk", label: "DUSK"}
    ] : []

    function fraction(stamp) {
        return available ? Math.max(0, Math.min(1, (stamp - solar.start) / (solar.end - solar.start))) : 0;
    }
    function eventFraction(key) {
        return available && solar[key] ? fraction(solar[key].epoch) : -1;
    }
    function pathHeight(f) {
        const rise = eventFraction("sunrise"), set = eventFraction("sunset");
        if (solar.state === "polar-day") return 0.72 + Math.sin(f * Math.PI) * 0.2;
        if (solar.state === "polar-night") return -0.42 - Math.cos(f * Math.PI * 2) * 0.12;
        if (rise < 0 || set < 0 || set <= rise) return 0;
        if (f >= rise && f <= set) return Math.sin((f - rise) / (set - rise) * Math.PI);
        const nightLength = 1 - set + rise;
        return -0.6 * Math.sin((f > set ? f - set : 1 - set + f) / nightLength * Math.PI);
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -10
        radius: Theme.radiusMedium
        color: Theme.controlRest
    }

    Text {
        anchors.left: parent.left; anchors.right: zoneLabel.left; anchors.rightMargin: 12
        text: root.available ? root.location.toUpperCase() : "DAY / NIGHT"
        elide: Text.ElideRight
        color: Theme.muted; font.family: Theme.fontMono; font.pixelSize: 10; font.letterSpacing: 1
    }
    Text {
        id: zoneLabel
        anchors.right: parent.right
        text: root.available ? (root.solar.state === "polar-day" ? "MIDNIGHT SUN · "
            : root.solar.state === "polar-night" ? "POLAR NIGHT · " : "") + (root.solar.zone_label || "") : ""
        color: Theme.accent; font.family: Theme.fontMono; font.pixelSize: 10
    }
    Canvas {
        id: field
        anchors.fill: parent; anchors.topMargin: 23; anchors.bottomMargin: 41
        visible: root.available
        antialiasing: true
        function yAt(f) { return height * 0.58 - root.pathHeight(f) * height * 0.48; }
        onPaint: {
            const ctx = getContext("2d"); ctx.reset();
            if (!root.available || width <= 0 || height <= 0) return;
            const horizon = height * 0.58;
            const dayStart = root.solar.state === "polar-day" ? 0 : root.eventFraction("sunrise");
            const dayEnd = root.solar.state === "polar-day" ? 1 : root.eventFraction("sunset");
            const dawn = root.eventFraction("dawn"), dusk = root.eventFraction("dusk");
            ctx.fillStyle = Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.045);
            ctx.fillRect(0, 0, width, height);
            if (dawn >= 0 && dusk > dawn) {
                ctx.fillStyle = Qt.rgba(Theme.rose.r, Theme.rose.g, Theme.rose.b, 0.075);
                ctx.fillRect(dawn * width, 0, (dusk - dawn) * width, height);
            }
            if (dayStart >= 0 && dayEnd > dayStart) {
                ctx.fillStyle = Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.10);
                ctx.fillRect(dayStart * width, 0, (dayEnd - dayStart) * width, height);
            }
            ctx.beginPath(); ctx.moveTo(0, horizon); ctx.lineTo(width, horizon);
            ctx.strokeStyle = Theme.line; ctx.lineWidth = 1; ctx.stroke();
            for (let pass = 0; pass < 2; pass++) {
                const limit = pass === 0 ? 1 : root.progress;
                if (limit <= 0) continue;
                ctx.beginPath();
                for (let i = 0; i <= 120; i++) {
                    const f = i / 120 * limit;
                    if (i === 0) ctx.moveTo(f * width, yAt(f)); else ctx.lineTo(f * width, yAt(f));
                }
                ctx.strokeStyle = pass === 0 ? Theme.lineBright : Theme.warning;
                ctx.lineWidth = pass === 0 ? 1.2 : 2; ctx.stroke();
            }
            for (const entry of root.events) {
                const f = root.eventFraction(entry.key);
                if (f < 0) continue;
                ctx.beginPath(); ctx.arc(f * width, yAt(f), 2.6, 0, Math.PI * 2);
                ctx.fillStyle = Theme.moon; ctx.fill();
            }
            if (root.isToday) {
                const x = root.progress * width, y = yAt(root.progress);
                ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, height);
                ctx.strokeStyle = Qt.rgba(Theme.moon.r, Theme.moon.g, Theme.moon.b, 0.25); ctx.stroke();
                ctx.beginPath(); ctx.arc(x, y, 5, 0, Math.PI * 2);
                ctx.fillStyle = Theme.warning; ctx.fill();
            }
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: requestPaint()
        Connections { target: root; function onSolarChanged() { field.requestPaint(); } function onEpochChanged() { field.requestPaint(); } }
        Connections { target: Theme; function onAccentChanged() { field.requestPaint(); } function onWarningChanged() { field.requestPaint(); } }
    }
    Row {
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        visible: root.available
        Repeater {
            model: root.events
            Column {
                required property var modelData
                width: root.width / 5; spacing: 4
                Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: modelData.label; color: Theme.muted; font.family: Theme.fontMono; font.pixelSize: root.width < 500 ? 8 : 9 }
                Text {
                    width: parent.width; horizontalAlignment: Text.AlignHCenter
                    text: root.solar[modelData.key] ? (root.solar[modelData.key].estimated ? "≈" : "") + root.solar[modelData.key].time : "—"
                    color: Theme.moon; font.family: Theme.fontMono; font.pixelSize: 11
                }
            }
        }
    }
    Rectangle {
        anchors.fill: parent; anchors.topMargin: 24
        visible: !root.available; radius: Theme.radiusMedium; color: Theme.controlRest
        Text {
            anchors.centerIn: parent; width: parent.width - 28
            text: root.unavailableText + "\nOPEN WEATHER SETTINGS"
            horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
            color: Theme.muted; font.family: Theme.fontMono; font.pixelSize: 10; lineHeight: 1.6
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.configureRequested() }
        Accessible.role: Accessible.Button
        Accessible.name: "Configure weather location for the solar timeline"
        Accessible.onPressAction: root.configureRequested()
    }
}
