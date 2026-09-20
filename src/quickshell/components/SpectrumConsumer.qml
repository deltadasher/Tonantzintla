import QtQuick
import "../services"

QtObject {
    id: root
    property bool active: true
    onActiveChanged: active ? Spectrum.acquire(root) : Spectrum.release(root)
    Component.onCompleted: if (active) Spectrum.acquire(root)
    Component.onDestruction: Spectrum.release(root)
}
