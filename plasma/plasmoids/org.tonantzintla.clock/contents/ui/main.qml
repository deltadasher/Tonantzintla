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
                    font.family: "JetBrains Mono"
                    font.pixelSize: 12
                    font.weight: Font.Bold
                }
                Rectangle {
                    width: 4; height: 4; radius: 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: Kirigami.Theme.focusColor
                }
                Text {
                    text: Qt.formatDate(root.now, "ddd dd MMM")
                    color: Kirigami.Theme.disabledTextColor
                    font.family: "JetBrains Mono"
                    font.pixelSize: 11
                    font.weight: Font.Medium
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
    fullRepresentation: Item {
        id: calRoot
        implicitWidth: 284
        implicitHeight: 332
        property int viewYear: root.now.getFullYear()
        property int viewMonth: root.now.getMonth()
        readonly property bool isCurrentMonth: viewYear === root.now.getFullYear() && viewMonth === root.now.getMonth()
        readonly property color accentColor: Kirigami.Theme.focusColor
        function linChannel(c) { return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4); }
        readonly property color accentFg: (0.2126 * linChannel(accentColor.r) + 0.7152 * linChannel(accentColor.g) + 0.0722 * linChannel(accentColor.b)) > 0.34 ? "#101016" : "#f8f7fc"
        function shiftMonth(delta) {
            const d = new Date(viewYear, viewMonth + delta, 1);
            viewYear = d.getFullYear();
            viewMonth = d.getMonth();
        }
        function cellDate(cellIndex) {
            const first = new Date(viewYear, viewMonth, 1);
            const mondayOffset = (first.getDay() + 6) % 7;
            return new Date(viewYear, viewMonth, 1 - mondayOffset + cellIndex);
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            // Large tabular clock header
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.formatTime(root.now, "HH:mm:ss")
                    color: calRoot.accentColor
                    font.family: "JetBrains Mono"
                    font.pixelSize: 32
                    font.weight: Font.Bold
                }
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.formatDate(root.now, "dddd, MMMM d, yyyy")
                    color: Kirigami.Theme.disabledTextColor
                    font.family: "JetBrains Mono"
                    font.pixelSize: 11
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.08)
            }

            // Month navigation bar
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Rectangle {
                    Layout.preferredWidth: 24; Layout.preferredHeight: 24; radius: 6
                    color: prevMo.containsMouse ? Kirigami.Theme.alternateBackgroundColor : "transparent"
                    Text { anchors.centerIn: parent; text: "‹"; color: Kirigami.Theme.textColor; font.family: "JetBrains Mono"; font.pixelSize: 14; font.bold: true }
                    MouseArea { id: prevMo; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: calRoot.shiftMonth(-1) }
                }
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.formatDate(new Date(calRoot.viewYear, calRoot.viewMonth, 1), "MMMM yyyy").toUpperCase()
                    color: Kirigami.Theme.textColor
                    font.family: "JetBrains Mono"
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    font.letterSpacing: 0.8
                }
                Rectangle {
                    visible: !calRoot.isCurrentMonth
                    Layout.preferredWidth: todayTxt.implicitWidth + 10; Layout.preferredHeight: 20; radius: 5
                    color: Kirigami.Theme.alternateBackgroundColor
                    Text { id: todayTxt; anchors.centerIn: parent; text: "TODAY"; color: calRoot.accentColor; font.family: "JetBrains Mono"; font.pixelSize: 9; font.weight: Font.Bold }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { calRoot.viewYear = root.now.getFullYear(); calRoot.viewMonth = root.now.getMonth(); } }
                }
                Rectangle {
                    Layout.preferredWidth: 24; Layout.preferredHeight: 24; radius: 6
                    color: nextMo.containsMouse ? Kirigami.Theme.alternateBackgroundColor : "transparent"
                    Text { anchors.centerIn: parent; text: "›"; color: Kirigami.Theme.textColor; font.family: "JetBrains Mono"; font.pixelSize: 14; font.bold: true }
                    MouseArea { id: nextMo; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: calRoot.shiftMonth(1) }
                }
            }

            // Weekday header
            GridLayout {
                Layout.fillWidth: true
                columns: 7
                columnSpacing: 2
                Repeater {
                    model: ["MO", "TU", "WE", "TH", "FR", "SA", "SU"]
                    Text {
                        required property string modelData
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        color: Kirigami.Theme.disabledTextColor
                        font.family: "JetBrains Mono"
                        font.pixelSize: 9
                        font.weight: Font.Bold
                    }
                }
            }

            // 6-week calendar grid
            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 7
                rowSpacing: 2
                columnSpacing: 2
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
                        radius: 7
                        color: isToday ? calRoot.accentColor : (dayHover.hovered && inMonth ? Kirigami.Theme.alternateBackgroundColor : "transparent")
                        HoverHandler { id: dayHover }
                        Text {
                            anchors.centerIn: parent
                            text: dayCell.dt.getDate()
                            color: dayCell.isToday ? calRoot.accentFg : Kirigami.Theme.textColor
                            opacity: dayCell.isToday ? 1.0 : (dayCell.inMonth ? 0.92 : 0.28)
                            font.family: "JetBrains Mono"
                            font.pixelSize: 11
                            font.weight: dayCell.isToday ? Font.Bold : Font.Medium
                        }
                    }
                }
            }
        }
    }
}
