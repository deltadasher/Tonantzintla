pragma ComponentBehavior: Bound
import QtQuick
import "../../../.."
import "../../../../services"

Item {
    id: root
    property var selectedStream: null
    readonly property real cardWidth: Math.min(230, width * 0.32)
    readonly property real rowHeight: 62
    function sourceIndex(node) { return Audio.graphSources.indexOf(node); }
    function targetIndex(node) { return Audio.graphTargets.indexOf(node); }
    function routeTo(node) {
        if (selectedStream && Audio.outputs.indexOf(node) >= 0) {
            Audio.moveStream(selectedStream, node);
            selectedStream = null;
        }
    }
    Connections {
        target: Audio
        function onRoutesChanged() { cables.requestPaint(); }
        function onGraphSourcesChanged() {
            if (root.sourceIndex(root.selectedStream) < 0) root.selectedStream = null;
            cables.requestPaint();
        }
        function onGraphTargetsChanged() { cables.requestPaint(); }
    }
    Flickable {
        id: field
        anchors.fill: parent
        anchors.bottomMargin: 44
        clip: true
        contentWidth: width
        contentHeight: Math.max(height, Math.max(Audio.graphSources.length, Audio.graphTargets.length) * root.rowHeight)
        Canvas {
            id: cables
            width: field.width
            height: field.contentHeight
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                for (const link of Audio.routes) {
                    const a = root.sourceIndex(link.source), b = root.targetIndex(link.target);
                    if (a < 0 || b < 0) continue;
                    const y1 = a * root.rowHeight + 26, y2 = b * root.rowHeight + 26;

                    // Ambient glow pass
                    ctx.beginPath();
                    ctx.moveTo(root.cardWidth, y1);
                    ctx.bezierCurveTo(width * 0.5, y1, width * 0.5, y2, width - root.cardWidth, y2);
                    ctx.strokeStyle = Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16);
                    ctx.lineWidth = 6;
                    ctx.stroke();

                    // Core cable
                    ctx.beginPath();
                    ctx.moveTo(root.cardWidth, y1);
                    ctx.bezierCurveTo(width * 0.5, y1, width * 0.5, y2, width - root.cardWidth, y2);
                    ctx.strokeStyle = Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.72);
                    ctx.lineWidth = 2;
                    ctx.stroke();
                }
            }
        }
        Repeater {
            model: [Audio.graphSources, Audio.graphTargets]
            Item {
                id: column
                required property int index
                required property var modelData
                readonly property bool sourceSide: index === 0
                x: sourceSide ? 0 : field.width - root.cardWidth
                width: root.cardWidth
                height: field.contentHeight
                Repeater {
                    model: column.modelData
                    Rectangle {
                        id: card
                        required property int index
                        required property var modelData
                        y: index * root.rowHeight
                        width: root.cardWidth
                        height: 52
                        radius: 12
                        readonly property bool actionable: column.sourceSide ? Audio.canRoute(modelData)
                            : root.selectedStream !== null && Audio.outputs.indexOf(modelData) >= 0
                        color: root.selectedStream === modelData ? Theme.controlActive
                            : pointer.containsMouse || activeFocus ? Theme.controlHover : Theme.elevated
                        border.width: 0
                        Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                        activeFocusOnTab: actionable
                        Accessible.role: Accessible.Button
                        Accessible.name: Audio.nodeTitle(modelData)
                        function activate() {
                            if (column.sourceSide && Audio.canRoute(modelData)) root.selectedStream = modelData;
                            else root.routeTo(modelData);
                        }
                        Keys.onReturnPressed: activate()
                        Keys.onSpacePressed: activate()
                        Text {
                            anchors.fill: parent
                            anchors.margins: 10
                            text: Audio.nodeTitle(card.modelData)
                            color: Theme.moon
                            font.family: Theme.fontMono
                            font.pixelSize: 11
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }
                        MouseArea {
                            id: pointer
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: card.actionable ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onPressed: if (column.sourceSide && Audio.canRoute(card.modelData)) root.selectedStream = card.modelData
                            onReleased: function(mouse) {
                                const point = mapToItem(field.contentItem, mouse.x, mouse.y);
                                if (column.sourceSide && point.x >= field.width - root.cardWidth) {
                                    const target = Audio.graphTargets[Math.floor(point.y / root.rowHeight)];
                                    if (target) root.routeTo(target);
                                } else if (!column.sourceSide) card.activate();
                            }
                        }
                    }
                }
            }
        }
        Text {
            anchors.centerIn: parent
            visible: Audio.graphSources.length === 0 && Audio.graphTargets.length === 0
            text: Audio.mixerAvailable ? "No audio nodes available" : "PipeWire is unavailable"
            color: Theme.muted
            font.family: Theme.fontMono
        }
    }
    Text {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 38
        text: Audio.routing || Audio.routeError ? Audio.routeStatus : root.selectedStream
            ? "Choose an output for " + Audio.nodeTitle(root.selectedStream)
            : Audio.routeStatus || "Drag playback to an output, or select each in turn. Cables show real connections."
        color: Audio.routeError ? Theme.warning : Theme.muted
        font.family: Theme.fontMono
        font.pixelSize: 10
        wrapMode: Text.WordWrap
    }
}
