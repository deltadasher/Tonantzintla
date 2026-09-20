import QtQuick
import QtQuick.Layouts
import "../.."
import "../../components"

Rectangle {
            id: root
            property var flow: null
            function clearResponse() { password.clear(); }
            function focusPrimary() { password.forceActiveFocus(); }
            implicitWidth: 500
            implicitHeight: content.implicitHeight + 48
            Keys.onEscapePressed: { password.clear(); if (flow) flow.cancelAuthenticationRequest(); }
            radius: 28; color: Theme.mantle
            border.color: Theme.accentLine; border.width: 1
            ColumnLayout {
                id: content
                anchors.fill: parent; anchors.margins: 24; spacing: 14
                WabiSabiBlackHole { Layout.alignment: Qt.AlignHCenter; Layout.preferredWidth: 86; Layout.preferredHeight: 58; diskColor: Theme.accent; horizonColor: Theme.void_ }
                Text { text: "Authentication required"; color: Theme.moon; font.family: Theme.fontDisplay; font.pixelSize: 22; font.bold: true }
                Text { Layout.fillWidth: true; text: root.flow ? root.flow.message : ""; textFormat: Text.PlainText; wrapMode: Text.WordWrap; color: Theme.moon; font.family: Theme.fontText; font.pixelSize: 14 }
                Flow {
                    Layout.fillWidth: true; spacing: 6
                    Repeater {
                        model: root.flow ? root.flow.identities : []
                        ActionButton {
                            required property var modelData
                            text: modelData.displayName || String(modelData.id)
                            selected: root.flow && root.flow.selectedIdentity === modelData
                            onClicked: { password.clear(); root.flow.selectedIdentity = modelData; }
                        }
                    }
                }
                Text { text: root.flow ? root.flow.inputPrompt : ""; color: Theme.muted; font.family: Theme.fontText; font.pixelSize: 12 }
                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 44
                    radius: 12; color: Theme.controlRest
                    border.width: password.activeFocus ? 2 : 0; border.color: Theme.accent
                    TextInput {
                        id: password
                        anchors.fill: parent; anchors.margins: 12
                        color: Theme.moon; font.family: Theme.fontText; font.pixelSize: 16
                        enabled: root.flow && root.flow.isResponseRequired
                        echoMode: root.flow && root.flow.responseVisible ? TextInput.Normal : TextInput.Password
                        Accessible.name: root.flow ? root.flow.inputPrompt : "Authentication response"
                        function submit() { if (root.flow && root.flow.isResponseRequired) { const response = text; clear(); root.flow.submit(response); } }
                        Keys.onReturnPressed: submit()
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: root.flow ? root.flow.supplementaryMessage : ""
                    visible: text.length > 0
                    textFormat: Text.PlainText; wrapMode: Text.WordWrap
                    color: root.flow && root.flow.supplementaryIsError ? Theme.danger : Theme.muted
                    font.family: Theme.fontText; font.pixelSize: 12
                }
                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    ActionButton { text: "Cancel"; onClicked: { password.clear(); if (root.flow) root.flow.cancelAuthenticationRequest(); } }
                    ActionButton { text: "Authenticate"; selected: true; enabled: root.flow && root.flow.isResponseRequired; onClicked: password.submit() }
                }
            }
        
    Connections {
        target: root.flow
        function onIsResponseRequiredChanged() { password.clear(); if (root.flow && root.flow.isResponseRequired) password.forceActiveFocus(); }
        function onAuthenticationFailed() { password.clear(); password.forceActiveFocus(); }
        function onAuthenticationRequestCancelled() { password.clear(); }
    }
}
