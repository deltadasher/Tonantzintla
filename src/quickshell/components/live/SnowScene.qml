import QtQuick
import QtQuick.Particles
import "../.."

// Two depth layers of snow. Moving the pointer parts the flakes; a click sends a gust.
Item {
    id: scene
    property var values: ({})
    property bool running: true
    property point pointer: Qt.point(-1, -1)
    property bool pointerActive: false

    readonly property real density: Math.max(20, Number(values.density) || 350)
    readonly property real wind: (Number(values.wind) || 0) * 28
    readonly property real fallSeconds: Math.max(6, height / 90)
    property real gust: 0

    function pulse(x, y) {
        gust = x < width / 2 ? 320 : -320;
        calm.restart();
    }
    NumberAnimation { id: calm; target: scene; property: "gust"; to: 0; duration: 2200; easing.type: Easing.OutCubic }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.darker(Theme.void_, 1.3) }
            GradientStop { position: 0.72; color: Theme.void_ }
            GradientStop { position: 1; color: Theme.elevated }
        }
    }

    ParticleSystem { id: flakes; running: true; paused: !scene.running }

    ImageParticle {
        system: flakes; groups: ["far"]
        source: "qrc:///particleresources/fuzzydot.png"
        color: Theme.moon; alpha: 0.38; colorVariation: 0
    }
    ImageParticle {
        system: flakes; groups: ["near"]
        source: "qrc:///particleresources/fuzzydot.png"
        color: Theme.moon; alpha: 0.9; colorVariation: 0
    }

    Emitter {
        system: flakes; group: "far"
        x: -scene.width * 0.25; y: -24; width: scene.width * 1.5; height: 1
        lifeSpan: scene.fallSeconds * 1900
        emitRate: scene.density * 0.6 / (scene.fallSeconds * 1.9)
        size: 5; sizeVariation: 2
        velocity: PointDirection { x: scene.wind * 0.5; y: scene.height / (scene.fallSeconds * 1.8); xVariation: 6; yVariation: 8 }
    }
    Emitter {
        system: flakes; group: "near"
        x: -scene.width * 0.25; y: -24; width: scene.width * 1.5; height: 1
        lifeSpan: scene.fallSeconds * 1100
        emitRate: scene.density * 0.4 / (scene.fallSeconds * 1.1)
        size: 11; sizeVariation: 5
        velocity: PointDirection { x: scene.wind; y: scene.height / scene.fallSeconds; xVariation: 12; yVariation: 22 }
    }

    Wander { system: flakes; xVariance: 36; pace: 28; affectedParameter: Wander.Position }
    Gravity {
        system: flakes; enabled: Math.abs(scene.gust) > 2
        angle: scene.gust > 0 ? 0 : 180; magnitude: Math.abs(scene.gust)
    }
    Attractor {
        system: flakes; enabled: scene.pointerActive
        pointX: scene.pointer.x; pointY: scene.pointer.y
        strength: -260000
        affectedParameter: Attractor.Position
        proportionalToDistance: Attractor.InverseQuadratic
    }
}
