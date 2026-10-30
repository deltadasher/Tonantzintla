import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../../.."
import "../../../../services"
import "../../../../components"

ColumnLayout {
    id: root
    spacing: 8
    readonly property var caps: ScreenExtract.capabilities
    readonly property var languages: caps.languages || []
    readonly property bool readyToCapture: !!caps.captureAvailable && !ScreenExtract.busy && !ScreenExtract.copyBusy
    readonly property string availability: !caps.state ? "Checking local tools…"
        : caps.state === "error" ? caps.message
        : !caps.captureAvailable ? "Install grim and slurp to select an area."
        : !caps.ocrAvailable && !caps.qrAvailable ? "Install Tesseract with a language model, or ZBar for QR codes."
        : !caps.ocrAvailable ? "Text reading needs Tesseract and a language model."
        : !caps.qrAvailable ? "QR reading needs ZBar (zbarimg)." : ""

    Component.onCompleted: ScreenExtract.refresh()
    RowLayout {
        Layout.fillWidth: true
        Text {
            Layout.fillWidth: true
            text: "READ FROM SCREEN"
            color: Theme.moon
            font.family: Theme.fontDisplay
            font.pixelSize: 16
            font.weight: Font.Bold
        }
        ActionButton {
            text: ScreenExtract.language === "eng" ? "English" : (ScreenExtract.language || "No language")
            implicitHeight: 28
            enabled: root.languages.length > 1 && !ScreenExtract.busy
            Accessible.name: "OCR language: " + text + ". Activate to choose the next installed language."
            onClicked: ScreenExtract.language = root.languages[(root.languages.indexOf(ScreenExtract.language) + 1) % root.languages.length]
            ToolTip.visible: hovered.hovered
            ToolTip.text: "OCR language · click to cycle installed languages"
            HoverHandler { id: hovered }
        }
        ActionButton {
            text: "Refresh"; implicitHeight: 28
            enabled: !ScreenExtract.busy
            onClicked: ScreenExtract.refresh()
            Accessible.name: "Check screen-reading tools and installed languages"
        }
    }
    RowLayout {
        Layout.fillWidth: true
        ActionButton {
            objectName: "readTextButton"
            text: "Read text"; selected: true
            enabled: root.readyToCapture && !!root.caps.ocrAvailable
            onClicked: ScreenExtract.start("ocr")
        }
        ActionButton {
            objectName: "readQrButton"
            text: "Scan QR"
            enabled: root.readyToCapture && !!root.caps.qrAvailable
            onClicked: ScreenExtract.start("qr")
        }
        Item { Layout.fillWidth: true }
        ActionButton {
            visible: ScreenExtract.busy
            text: "Cancel"
            onClicked: ScreenExtract.cancel()
        }
        ActionButton {
            visible: !!ScreenExtract.text
            text: "Clear"
            enabled: !ScreenExtract.copyBusy
            onClicked: ScreenExtract.clear()
        }
        ActionButton {
            objectName: "copyExtractButton"
            visible: !!ScreenExtract.text
            text: ScreenExtract.copied ? "Copied" : "Copy"
            pending: ScreenExtract.copyBusy
            onClicked: ScreenExtract.copy()
        }
    }
    Text {
        Layout.fillWidth: true
        text: ScreenExtract.state === "idle" && root.availability ? root.availability : ScreenExtract.message
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: ScreenExtract.state === "error" ? Theme.danger : Theme.muted
        font.family: Theme.fontText
        font.pixelSize: 11
    }
    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 54
        color: Theme.mantle
        radius: 8
        border.width: extracted.activeFocus ? 1 : 0
        border.color: Theme.accent
        Text {
            anchors.centerIn: parent
            visible: !ScreenExtract.text
            text: ScreenExtract.busy ? "Reading locally…" : "Text and QR contents appear here"
            color: Theme.muted
            font.family: Theme.fontText
            font.pixelSize: 11
        }
        Flickable {
            id: scroll
            anchors.fill: parent
            anchors.margins: 10
            clip: true
            contentWidth: width
            contentHeight: extracted.height
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}
            TextEdit {
                id: extracted
                objectName: "extractedText"
                width: scroll.width - 12
                height: Math.max(scroll.height, contentHeight)
                text: ScreenExtract.text
                textFormat: TextEdit.PlainText
                readOnly: true
                selectByMouse: true
                activeFocusOnTab: !!text
                wrapMode: TextEdit.Wrap
                color: Theme.moon
                selectionColor: Theme.accent
                selectedTextColor: Theme.void_
                font.family: Theme.fontMono
                font.pixelSize: 12
                Accessible.name: ScreenExtract.kind === "qr" ? "QR contents" : "Extracted text"
                onTextChanged: { cursorPosition = 0; scroll.contentY = 0; }
            }
        }
    }
}
