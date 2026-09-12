import QtQuick

// One geometry feeds the backing, clipping boundary and contents. No timers or
// independent easing: SurfaceTransition owns progress, including interruptions.
QtObject {
    property rect origin: Qt.rect(0, 0, 48, 40)
    property rect destination: Qt.rect(0, 0, 640, 480)
    property real progress: 0
    property bool motion: true
    readonly property real amount: motion ? Math.max(0, Math.min(1, progress)) : 1
    readonly property real width: Math.max(1, mix(origin.width, destination.width))
    readonly property real height: Math.max(1, mix(origin.height, destination.height))
    readonly property real x: mix(origin.x, destination.x)
    readonly property real y: mix(origin.y, destination.y)
    readonly property real radius: Math.min(width / 2, height / 2, mix(origin.height / 2, 26))
    function mix(from, to) { return from + (to - from) * amount; }
}
