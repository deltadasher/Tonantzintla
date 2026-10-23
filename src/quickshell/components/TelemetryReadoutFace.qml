import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import ".."

Loader {
    id: root
    property string code: "CPU"
    property string value: "0%"
    property real level: 0
    property string variant: "numeric"
    property bool compact: false
    property bool vertical: false
    sourceComponent: variant === "arc" ? arcFace : variant === "trace" ? traceFace : numericFace

    Component {
        id: numericFace
        RowLayout {
            spacing: 4
            Text { text: root.code; color: Theme.muted; font.family: Theme.fontText; font.pixelSize: Theme.textCaption; font.weight: Font.DemiBold; font.letterSpacing: 0.45 }
            Text { text: root.value; color: Theme.moon; font.family: Theme.fontText; font.pixelSize: Theme.textLabel; font.weight: Font.DemiBold }
        }
    }
    Component {
        id: arcFace
        Item {
            implicitWidth: root.vertical ? 32 : root.compact ? 64 : 72
            implicitHeight: root.vertical ? 52 : 30
            Shape {
                width: 26; height: 26; x: root.vertical ? 3 : 0; y: 2
                ShapePath {
                    strokeColor: Theme.barHairlineHover; strokeWidth: 2; fillColor: "transparent"
                    startX: 5; startY: 21
                    PathAngleArc { centerX:13;centerY:13;radiusX:11;radiusY:11;startAngle:135;sweepAngle:270 }
                }
                ShapePath {
                    strokeColor: Theme.accent; strokeWidth: 2; fillColor: "transparent"
                    startX: 5; startY: 21
                    PathAngleArc { centerX:13;centerY:13;radiusX:11;radiusY:11;startAngle:135;sweepAngle:270*Math.max(0,Math.min(1,root.level)) }
                }
            }
            Column {
                x: root.vertical ? 0 : 30; y: root.vertical ? 29 : 2
                width: root.vertical ? parent.width : parent.width-30
                Text {width:parent.width;text:root.code;color:Theme.muted;font.family:Theme.fontMono;font.pixelSize:9;horizontalAlignment:root.vertical?Text.AlignHCenter:Text.AlignLeft}
                Text {width:parent.width;text:root.value;color:Theme.moon;font.family:Theme.fontMono;font.pixelSize:10;horizontalAlignment:root.vertical?Text.AlignHCenter:Text.AlignLeft}
            }
        }
    }
    Component {
        id: traceFace
        Item {
            id: trace
            objectName: "telemetry-trace"
            implicitWidth: root.vertical ? 32 : root.compact ? 60 : 68
            implicitHeight: root.vertical ? 42 : 30
            // Local presentation history only: existing service changes supply samples.
            // Unmounting this face releases its fixed 16-value history.
            property var samples: [Math.max(0, Math.min(1, root.level))]
            function append() { samples = samples.concat([Math.max(0, Math.min(1, root.level))]).slice(-16); }
            Connections { target: root; enabled: root.visible; function onLevelChanged() { trace.append(); } }
            readonly property var points: {
                const result=[];
                for(let i=0;i<samples.length;i++) result.push(Qt.point(i*(width-2)/15, 13-samples[i]*12));
                return result;
            }
            Shape {
                width: parent.width; height: 14
                ShapePath {
                    strokeColor: Theme.cyan; strokeWidth: 1.5; fillColor: "transparent"
                    startX: trace.points.length ? trace.points[0].x : 0
                    startY: trace.points.length ? trace.points[0].y : 13
                    PathPolyline { path: trace.points }
                }
            }
            Text {
                y:16; width:parent.width
                text: root.code + (root.vertical ? "\n" : " ") + root.value
                color:Theme.moon;font.family:Theme.fontMono;font.pixelSize:9
                horizontalAlignment:root.vertical?Text.AlignHCenter:Text.AlignLeft
            }
        }
    }
}
