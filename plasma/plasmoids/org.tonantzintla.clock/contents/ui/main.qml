pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore

PlasmoidItem {
    id: root
    property date now: new Date()
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    readonly property color accentColor: Kirigami.Theme.focusColor
    function linChannel(c) { return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4); }
    readonly property color accentFg: (0.2126 * linChannel(accentColor.r) + 0.7152 * linChannel(accentColor.g) + 0.0722 * linChannel(accentColor.b)) > 0.34 ? "#101016" : "#f8f7fc"
    // JetBrains Mono when it is installed; otherwise the system fixed-width font, so digits never shift.
    readonly property string monoFamily: Qt.fontFamilies().indexOf("JetBrains Mono") >= 0
        ? "JetBrains Mono"
        : Kirigami.Theme.fixedWidthFont.family

    readonly property real lunarCycle: {
        const refMs = Date.UTC(2000, 0, 6, 18, 14, 0);
        const days = (now.getTime() - refMs) / 86400000.0;
        const synodic = 29.53058867;
        let phase = (days % synodic) / synodic;
        if (phase < 0) phase += 1.0;
        return phase;
    }
    // The disc only changes visibly every few hours; repaint on that step, not every second.
    readonly property int moonStep: Math.round(lunarCycle * 240)

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    compactRepresentation: Item {
        Layout.minimumWidth: clockPill.implicitWidth
        Layout.preferredWidth: clockPill.implicitWidth
        Layout.maximumWidth: clockPill.implicitWidth
        Layout.fillHeight: true

        Rectangle {
            id: clockPill
            anchors.centerIn: parent
            implicitWidth: clockRow.implicitWidth + 18
            implicitHeight: 26
            radius: 8
            color: clockMouse.containsMouse || root.expanded ? Kirigami.Theme.alternateBackgroundColor : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }

            Row {
                id: clockRow
                anchors.centerIn: parent
                spacing: 8

                Text {
                    text: Qt.formatTime(root.now, "HH:mm:ss")
                    color: Kirigami.Theme.textColor
                    font.family: root.monoFamily
                    font.pixelSize: 12
                    font.weight: Font.Bold
                }
                Rectangle {
                    width: 4; height: 4; radius: 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.accentColor
                }
                Text {
                    text: Qt.formatDate(root.now, "ddd dd MMM")
                    color: Kirigami.Theme.disabledTextColor
                    font.family: root.monoFamily
                    font.pixelSize: 11
                    font.weight: Font.Medium
                }
                Canvas {
                    id: barMoon
                    width: 12; height: 12
                    anchors.verticalCenter: parent.verticalCenter
                    antialiasing: true
                    Connections {
                        target: root
                        function onMoonStepChanged() { barMoon.requestPaint(); }
                    }
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        const cx = 6, cy = 6, r = 4.6;
                        ctx.fillStyle = "rgba(140,142,158,0.22)";
                        ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.fill();
                        const phase = root.lunarCycle;
                        const waxing = phase < 0.5;
                        const k = Math.cos(phase * 2.0 * Math.PI);
                        ctx.save();
                        ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.clip();
                        ctx.fillStyle = "#eee9dc";
                        ctx.beginPath();
                        ctx.arc(cx, cy, r, waxing ? -Math.PI * 0.5 : Math.PI * 0.5, waxing ? Math.PI * 0.5 : Math.PI * 1.5);
                        ctx.closePath(); ctx.fill();
                        ctx.fillStyle = (k >= 0) ? "#16161d" : "#eee9dc";
                        ctx.beginPath();
                        ctx.ellipse(cx - Math.abs(k) * r, cy - r, Math.abs(k) * r * 2, r * 2);
                        ctx.fill();
                        ctx.restore();
                        ctx.strokeStyle = "rgba(238,233,220,0.24)";
                        ctx.lineWidth = 0.75;
                        ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.stroke();
                    }
                }
            }
            MouseArea {
                id: clockMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.expanded = !root.expanded
            }
        }
    }

    // ULTRA-CLEAN GLSL SCALLOPED CHRONOMETER & CALENDAR POPUP
    fullRepresentation: Item {
        id: calRoot
        implicitWidth: 312
        implicitHeight: 382
        property int viewYear: root.now.getFullYear()
        property int viewMonth: root.now.getMonth()
        readonly property bool isCurrentMonth: viewYear === root.now.getFullYear() && viewMonth === root.now.getMonth()
        // Week start and weekend follow the system region instead of assuming Monday and Sat/Sun.
        readonly property int firstDay: Qt.locale().firstDayOfWeek
        readonly property var workDays: Qt.locale().weekDays

        // Continuous sub-second timestamp for buttery 60-144Hz sweeping golden second comet
        property real smoothSecs: root.now.getSeconds() + root.now.getMilliseconds() / 1000.0
        property real smoothMins: root.now.getMinutes() + smoothSecs / 60.0
        property real smoothHrs: (root.now.getHours() % 12) + smoothMins / 60.0

        FrameAnimation {
            running: calRoot.visible
            onTriggered: {
                const d = new Date();
                const s = d.getSeconds() + d.getMilliseconds() / 1000.0;
                const m = d.getMinutes() + s / 60.0;
                calRoot.smoothSecs = s;
                calRoot.smoothMins = m;
                calRoot.smoothHrs = (d.getHours() % 12) + m / 60.0;
            }
        }

        Connections {
            target: root
            function onMoonStepChanged() {
                if (calRoot.visible) popupMoon.requestPaint();
            }
        }
        onVisibleChanged: {
            if (calRoot.visible) popupMoon.requestPaint();
        }

        function shiftMonth(delta) {
            const d = new Date(viewYear, viewMonth + delta, 1);
            viewYear = d.getFullYear();
            viewMonth = d.getMonth();
        }
        function cellDate(cellIndex) {
            const first = new Date(viewYear, viewMonth, 1);
            const lead = (first.getDay() - firstDay + 7) % 7;
            return new Date(viewYear, viewMonth, 1 - lead + cellIndex);
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                // GPU SDF 12-Lobed Scalloped Chronometer Shader
                ShaderEffect {
                    id: analogDial
                    Layout.preferredWidth: 88
                    Layout.preferredHeight: 88
                    property real uHourAngle: (calRoot.smoothHrs / 12.0) * 6.2831853 - 1.5707963
                    property real uMinAngle: (calRoot.smoothMins / 60.0) * 6.2831853 - 1.5707963
                    property real uSecAngle: (calRoot.smoothSecs / 60.0) * 6.2831853 - 1.5707963
                    property vector2d uResolution: Qt.vector2d(width, height)
                    property color uAccent: root.accentColor
                    property color uText: Kirigami.Theme.textColor
                    property color uSurface: Kirigami.Theme.alternateBackgroundColor
                    fragmentShader: Qt.resolvedUrl("../shaders/clock_dial.frag.qsb")
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5
                    Text {
                        text: Qt.formatTime(root.now, "HH:mm:ss")
                        color: root.accentColor
                        font.family: root.monoFamily
                        font.pixelSize: 24
                        font.weight: Font.Bold
                    }
                    Row {
                        spacing: 7
                        Canvas {
                            id: popupMoon
                            width: 13; height: 13
                            anchors.verticalCenter: parent.verticalCenter
                            antialiasing: true
                            onPaint: {
                                const ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                const cx = 6.5, cy = 6.5, r = 5.0;
                                ctx.fillStyle = "rgba(140,142,158,0.22)";
                                ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.fill();
                                const phase = root.lunarCycle;
                                const waxing = phase < 0.5;
                                const k = Math.cos(phase * 2.0 * Math.PI);
                                ctx.save();
                                ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.clip();
                                ctx.fillStyle = "#eee9dc";
                                ctx.beginPath();
                                ctx.arc(cx, cy, r, waxing ? -Math.PI * 0.5 : Math.PI * 0.5, waxing ? Math.PI * 0.5 : Math.PI * 1.5);
                                ctx.closePath(); ctx.fill();
                                ctx.fillStyle = (k >= 0) ? "#16161d" : "#eee9dc";
                                ctx.beginPath();
                                ctx.ellipse(cx - Math.abs(k) * r, cy - r, Math.abs(k) * r * 2, r * 2);
                                ctx.fill();
                                ctx.restore();
                                ctx.strokeStyle = "rgba(238,233,220,0.24)";
                                ctx.lineWidth = 0.75;
                                ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.stroke();
                            }
                        }
                        Text {
                            text: Qt.formatDate(root.now, "dddd, MMM d")
                            color: Kirigami.Theme.disabledTextColor
                            font.family: root.monoFamily
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.06)
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Rectangle {
                    Layout.preferredWidth: 26; Layout.preferredHeight: 26; radius: 7
                    color: prevMo.containsMouse ? Kirigami.Theme.alternateBackgroundColor : "transparent"
                    Behavior on color { ColorAnimation { duration: 110 } }
                    Text { anchors.centerIn: parent; text: "‹"; color: prevMo.containsMouse ? root.accentColor : Kirigami.Theme.textColor; font.family: root.monoFamily; font.pixelSize: 15; font.bold: true }
                    MouseArea { id: prevMo; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: calRoot.shiftMonth(-1) }
                }
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.formatDate(new Date(calRoot.viewYear, calRoot.viewMonth, 1), "MMMM yyyy")
                    color: Kirigami.Theme.textColor
                    font.family: root.monoFamily
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: !calRoot.isCurrentMonth ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            calRoot.viewYear = root.now.getFullYear();
                            calRoot.viewMonth = root.now.getMonth();
                        }
                    }
                }
                Rectangle {
                    visible: !calRoot.isCurrentMonth
                    Layout.preferredWidth: todayTxt.implicitWidth + 12; Layout.preferredHeight: 22; radius: 6
                    color: Kirigami.Theme.alternateBackgroundColor
                    Text { id: todayTxt; anchors.centerIn: parent; text: "Today"; color: root.accentColor; font.family: root.monoFamily; font.pixelSize: 10; font.weight: Font.Bold }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { calRoot.viewYear = root.now.getFullYear(); calRoot.viewMonth = root.now.getMonth(); } }
                }
                Rectangle {
                    Layout.preferredWidth: 26; Layout.preferredHeight: 26; radius: 7
                    color: nextMo.containsMouse ? Kirigami.Theme.alternateBackgroundColor : "transparent"
                    Behavior on color { ColorAnimation { duration: 110 } }
                    Text { anchors.centerIn: parent; text: "›"; color: nextMo.containsMouse ? root.accentColor : Kirigami.Theme.textColor; font.family: root.monoFamily; font.pixelSize: 15; font.bold: true }
                    MouseArea { id: nextMo; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: calRoot.shiftMonth(1) }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 7
                columnSpacing: 2
                Repeater {
                    model: 7
                    Text {
                        required property int index
                        readonly property int weekday: (calRoot.firstDay + index) % 7
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: Qt.locale().dayName(weekday, Locale.NarrowFormat)
                        color: calRoot.workDays.indexOf(weekday) < 0
                            ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.70)
                            : Kirigami.Theme.disabledTextColor
                        font.family: root.monoFamily
                        font.pixelSize: 10
                        font.weight: Font.Bold
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                WheelHandler {
                    onWheel: function(event) {
                        if (event.angleDelta.y !== 0) calRoot.shiftMonth(event.angleDelta.y < 0 ? 1 : -1);
                    }
                }

                GridLayout {
                    anchors.fill: parent
                    columns: 7
                    rowSpacing: 3
                    columnSpacing: 3
                    Repeater {
                        model: 42
                        Rectangle {
                            id: dayCell
                            required property int index
                            readonly property date dt: calRoot.cellDate(index)
                            readonly property bool inMonth: dt.getMonth() === calRoot.viewMonth
                            readonly property bool isToday: dt.getFullYear() === root.now.getFullYear() && dt.getMonth() === root.now.getMonth() && dt.getDate() === root.now.getDate()
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28
                            radius: 8
                            color: isToday
                                ? root.accentColor
                                : (dayHover.hovered && inMonth ? Kirigami.Theme.alternateBackgroundColor : "transparent")
                            Behavior on color { ColorAnimation { duration: 100 } }
                            HoverHandler { id: dayHover }
                            Text {
                                anchors.centerIn: parent
                                text: dayCell.dt.getDate()
                                color: dayCell.isToday ? root.accentFg : Kirigami.Theme.textColor
                                opacity: dayCell.isToday ? 1.0 : (dayCell.inMonth ? 0.92 : 0.24)
                                font.family: root.monoFamily
                                font.pixelSize: 11
                                font.weight: dayCell.isToday ? Font.Bold : Font.Medium
                            }
                        }
                    }
                }
            }
        }
    }
}
