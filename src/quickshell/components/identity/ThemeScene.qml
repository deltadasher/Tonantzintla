pragma ComponentBehavior: Bound
import QtQuick
import "SceneDrawing.js" as Drawing

// Portable artwork shared by Umbra and the greeter. No shell or login state.
Item {
    id: root
    property string identity: "wabi-sabi"
    property color accent: Drawing.approvedAccent(identity)
    property bool lightMode: false
    property bool active: true
    property bool motion: true
    property url iconSource: Qt.resolvedUrl("../../assets/theme-marks/" + identity + ".svg")
    readonly property color backgroundColor: Drawing.background(identity, lightMode)
    readonly property color foregroundColor: lightMode ? "#24272B" : "#F3F1ED"
    readonly property color mutedColor: Drawing.mix(foregroundColor, backgroundColor, 0.30)
    readonly property color accentColor: Drawing.readableAccent(accent, backgroundColor, foregroundColor)
    readonly property color dangerColor: Drawing.readableAccent(lightMode ? "#a93649" : "#ed7d8f", backgroundColor, foregroundColor)
    readonly property bool portrait: height > width * 1.12
    // The entire square fits in a reserved region. Every scene keeps its painted
    // geometry and motion inside 80..920, so nothing meets an edge.
    readonly property real artboardSize: Math.max(0, portrait
        ? Math.min(width * 0.90, height * 0.36)
        : Math.min(width * 0.52, height * 0.84))
    readonly property rect artRect: Qt.rect(
        portrait ? (width - artboardSize) * 0.5 : width * 0.44 + (width * 0.52 - artboardSize) * 0.5,
        portrait ? height * 0.04 : (height - artboardSize) * 0.5,
        artboardSize, artboardSize)
    // Shared placement contract for lock and greeter hosts. Portrait clocks and
    // authentication controls belong below the complete illustration.
    readonly property real suggestedClockY: height * (portrait ? 0.43 : 0.29)
    readonly property real suggestedInputY: height * (portrait ? 0.65 : 0.58)
    readonly property var mark: Drawing.markPlacement(identity)
    readonly property var layers: Drawing.layers(identity)
    readonly property int markIndex: {
        for (let i = 0; i < layers.length; i++) if (layers[i].logo) return i;
        return layers.length;
    }
    readonly property real unit: artboardSize / 1000
    // Seconds on one shared clock. Every layer derives its pose from it, so
    // nothing repaints while it moves. It rests at zero when motion stops.
    property real time: 0

    Rectangle { anchors.fill: parent; color: root.backgroundColor }

    Item {
        id: illustration
        objectName: "themeSceneArtboard"
        width: root.artRect.width
        height: width
        x: root.artRect.x
        y: root.artRect.y

        Repeater {
            model: root.layers
            delegate: Item {
                id: sceneLayer
                required property var modelData
                required property int index
                readonly property var box: modelData.box
                readonly property var origin: modelData.origin || [box[0] + box[2] / 2, box[1] + box[3] / 2]
                readonly property var pose: modelData.motion ? Drawing.pose(modelData.motion, root.time) : Drawing.REST
                objectName: "themeSceneLayer_" + modelData.name
                x: (box[0] + pose.x) * root.unit
                y: (box[1] + pose.y) * root.unit
                width: box[2] * root.unit
                height: box[3] * root.unit
                opacity: pose.o
                // An orbiting body passes behind the mark on the far half of its path.
                z: modelData.orbit && pose.front < 0 ? root.markIndex - 0.5 : index
                transform: [
                    Scale {
                        origin.x: (sceneLayer.origin[0] - sceneLayer.box[0]) * root.unit
                        origin.y: (sceneLayer.origin[1] - sceneLayer.box[1]) * root.unit
                        xScale: sceneLayer.pose.sx
                        yScale: sceneLayer.pose.sy
                    },
                    Rotation {
                        origin.x: (sceneLayer.origin[0] - sceneLayer.box[0]) * root.unit
                        origin.y: (sceneLayer.origin[1] - sceneLayer.box[1]) * root.unit
                        angle: (sceneLayer.modelData.rotate || 0) + sceneLayer.pose.r
                    }
                ]

                Loader {
                    anchors.fill: parent
                    sourceComponent: sceneLayer.modelData.logo === true ? markImage : sceneryCanvas
                }
                // The approved SVG itself, never recoloured or redrawn.
                Component {
                    id: markImage
                    Image {
                        source: root.iconSource
                        sourceSize.width: Math.ceil(width * 2)
                        sourceSize.height: Math.ceil(height * 2)
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }
                }
                // Scenery is painted once into a cache sized to its own box.
                Component {
                    id: sceneryCanvas
                    Canvas {
                        id: artwork
                        antialiasing: true
                        renderTarget: Canvas.Image
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.reset();
                            if (width <= 0) return;
                            ctx.scale(width / sceneLayer.box[2], height / sceneLayer.box[3]);
                            ctx.translate(-sceneLayer.box[0], -sceneLayer.box[1]);
                            Drawing.paintLayer(ctx, root.identity, sceneLayer.modelData.name, root.accent,
                                               root.backgroundColor, root.foregroundColor, root.lightMode);
                        }
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        Connections {
                            target: root
                            function onAccentChanged() { artwork.requestPaint(); }
                            function onLightModeChanged() { artwork.requestPaint(); }
                        }
                    }
                }
            }
        }
    }

    NumberAnimation on time {
        id: clock
        from: 0; to: Drawing.LOOP
        duration: Drawing.LOOP * 1000
        loops: Animation.Infinite
        running: root.active && root.visible && root.motion && root.artboardSize > 0
        onRunningChanged: if (!running) root.time = 0
    }
}
