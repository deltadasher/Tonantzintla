import QtQuick
import ".."
import "ClockNotation.js" as Notation

// A pure face: its host owns time acquisition and can share one minute clock.
Item {
    id: root
    property color accentColor: Theme.accent
    property color foregroundColor: Theme.moon
    property color mutedColor: Theme.muted
    property date dateTime: new Date()
    property string variant: "compact"
    property bool active: true
    readonly property string timeText: Notation.time(dateTime, Settings.clock12h)
    readonly property string dateText: Qt.formatDateTime(dateTime, "ddd, d MMM")
    implicitWidth: 260
    implicitHeight: 180
    Accessible.role: Accessible.StaticText
    Accessible.name: timeText + ", " + dateText
    Loader {
        anchors.fill: parent
        active: root.active
        sourceComponent: root.variant === "orbital" ? orbital
            : root.variant === "luminous" ? luminous
            : root.variant === "typographic" ? typography : compact
    }
    Component {
        id: compact
        Column {
            spacing: 6
            Text {
                width: parent.width
                height: parent.height * .60
                text: root.timeText
                color: root.foregroundColor
                font.family: Theme.fontMono
                font.pixelSize: Math.min(root.width * .24, root.height * .56)
                font.weight: Font.Light
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                fontSizeMode: Text.Fit
                minimumPixelSize: 12
            }
            Text {
                width: parent.width
                text: root.dateText
                color: root.mutedColor
                font.family: Theme.fontText
                font.pixelSize: Math.min(18, root.height * .12)
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
    Component {
        id: orbital
        Item {
            Canvas {
                id: dial
                width: Math.min(parent.width,384)
                height: Math.min(parent.height,384)
                transform: Scale { xScale: root.width / Math.max(1,dial.width); yScale: root.height / Math.max(1,dial.height) }
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                Connections { target: root; function onDateTimeChanged() { dial.requestPaint(); } }
                Connections { target: root; function onAccentColorChanged() { dial.requestPaint(); } function onForegroundColorChanged() { dial.requestPaint(); } function onMutedColorChanged() { dial.requestPaint(); } }
                onPaint: {
                    const ctx = getContext("2d"); ctx.reset();
                    const cx=width/2, cy=height/2, radius=Math.min(width,height)*.44;
                    ctx.strokeStyle=Theme.line; ctx.lineWidth=1;
                    ctx.beginPath(); ctx.arc(cx,cy,radius,0,Math.PI*2); ctx.stroke();
                    ctx.beginPath(); ctx.arc(cx,cy,radius*.78,0,Math.PI*2); ctx.stroke();
                    for(let i=0;i<12;i++) {
                        const a=i*Math.PI/6-Math.PI/2;
                        ctx.fillStyle=i%3===0?root.foregroundColor:root.mutedColor;
                        ctx.beginPath(); ctx.arc(cx+Math.cos(a)*radius,cy+Math.sin(a)*radius,i%3===0?2:1,0,Math.PI*2); ctx.fill();
                    }
                    const a=(root.dateTime.getMinutes()/60)*Math.PI*2-Math.PI/2;
                    ctx.fillStyle=root.accentColor;
                    ctx.beginPath(); ctx.arc(cx+Math.cos(a)*radius,cy+Math.sin(a)*radius,5,0,Math.PI*2); ctx.fill();
                }
            }
            Column {
                anchors.centerIn: parent
                spacing: 4
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.timeText; color: root.foregroundColor; font.family: Theme.fontMono; font.pixelSize: Math.min(root.width*(Settings.clock12h ? .13 : .18),root.height*.23) }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.dateText; color: root.mutedColor; font.family: Theme.fontText; font.pixelSize: Math.min(14,root.height*.08) }
            }
        }
    }
    Component {
        id: luminous
        Item {
            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width*.92,parent.height*1.9)
                height: Math.min(parent.height*.72,width*.52)
                radius: height/2
                color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, .13)
                border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, .52)
                border.width: 1
                Text { anchors.centerIn: parent; text: root.timeText; color: root.accentColor; font.family: Theme.fontMono; font.pixelSize: Math.min(parent.width*(Settings.clock12h ? .15 : .22),parent.height*.55); font.weight: Font.Light }
            }
            Text { anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter; text: root.dateText; color: root.mutedColor; font.family: Theme.fontText; font.pixelSize: Math.min(16,root.height*.10) }
        }
    }
    Component {
        id: typography
        Item {
            Text {
                anchors.fill: parent
                text: Notation.stacked(root.dateTime, Settings.clock12h)
                color: root.foregroundColor
                font.family: Theme.fontDisplay
                font.pixelSize: Math.min(root.width*.55,root.height*.47)
                font.weight: Font.Light
                lineHeight: .85
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            Text {
                anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
                text: Notation.period(root.dateTime, Settings.clock12h)
                color: root.mutedColor; font.family: Theme.fontText
                font.pixelSize: Math.min(16, root.height * .08)
            }
            Rectangle { x: parent.width*.08; y: parent.height*.48; width: parent.width*.16; height: 2; color: root.accentColor }
        }
    }
}
