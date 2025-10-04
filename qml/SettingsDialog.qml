import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Material
import Odizinne.OdznDrive

Dialog {
    title: "Settings"
    width: 400
    standardButtons: Dialog.NoButton
    closePolicy: ConnectionManager.connected ? Popup.CloseOnEscape : Popup.NoAutoClose
    modal: true

    footer: DialogButtonBox {
        Button {
            flat: true
            text: "Close"
            enabled: ConnectionManager.connected
            onClicked: close()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        RowLayout {
            Label {
                text: "Server URL"
                Layout.fillWidth: true
            }

            TextField {
                id: urlField
                Layout.preferredWidth: 200
                Layout.preferredHeight: 35
                placeholderText: "ws://localhost:8888"
                text: UserSettings.serverUrl
                enabled: !ConnectionManager.connected
                onTextChanged: UserSettings.serverUrl = text.trim()
            }
        }

        RowLayout {
            Label {
                text: "Server Password"
                Layout.fillWidth: true
            }

            TextField {
                id: passwordField
                Layout.preferredWidth: 200
                Layout.preferredHeight: 35
                placeholderText: "Password"
                text: UserSettings.serverPassword
                echoMode: TextInput.Password
                enabled: !ConnectionManager.connected
                onTextChanged: UserSettings.serverPassword = text.trim()
            }
        }

        RowLayout {
            Label {
                text: "Autoconnect"
                Layout.fillWidth: true
            }

            CheckBox {
                checked: UserSettings.autoconnect
                onClicked: UserSettings.autoconnect = checked
            }
        }

        RowLayout {
            Item {
                Layout.fillWidth: true
            }

            Button {
                text: ConnectionManager.connected ? "Disconnect" : "Connect"
                Material.roundedScale: Material.ExtraSmallScale
                onClicked: {
                    if (ConnectionManager.connected) {
                        ConnectionManager.disconnect()
                    } else {
                        if (urlField.text.trim() === "" || passwordField.text.trim() === "") {
                            return
                        }
                        ConnectionManager.connectToServer(urlField.text.trim(), passwordField.text.trim())
                    }
                }
            }
        }

        RowLayout {
            Label {
                text: "Sort folders before files"
                Layout.fillWidth: true
            }

            Switch {
                checked: UserSettings.foldersFirst
                onClicked: {
                    UserSettings.foldersFirst = checked
                    ConnectionManager.listDirectory(FileModel.currentPath, checked)
                }
            }
        }
    }
}
