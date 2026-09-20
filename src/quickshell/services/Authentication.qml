pragma Singleton
import QtQuick

QtObject {
    signal cancelRequested()
    property bool registered: false
    property string status: "Starting authentication agent…"
}
