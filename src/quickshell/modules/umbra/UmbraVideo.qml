import QtQuick

// Prepared bounded GIF only: QtMultimedia/FFmpeg is never loaded in the shell.
// cache:false keeps decoded animation frames out of the image cache.
AnimatedImage {
    id: root
    readonly property bool ready: status === Image.Ready
    readonly property bool failed: status === Image.Error
    playing: true
    cache: false
    asynchronous: true
    fillMode: Image.PreserveAspectCrop
    Component.onDestruction: { playing = false; source = ""; }
}
