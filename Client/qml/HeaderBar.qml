import QtQuick
import QtQuick.Controls.Material
import QtQuick.Layouts
import Odizinne.OdznDriveClient

Rectangle {
    id: root
    color: Material.primary

    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 15

        Label {
            text: "OdznDrive"
            font.pixelSize: 20
            font.bold: true
            color: Material.background
        }

        Item {
            Layout.fillWidth: true
        }

        Label {
            text: "Server URL:"
            color: Material.background
        }

        TextField {
            id: urlField
            Layout.preferredWidth: 200
            placeholderText: "ws://localhost:8888"
            text: "ws://localhost:8888"
            enabled: !ConnectionManager.connected
        }

        Label {
            text: "Password:"
            color: Material.background
        }

        TextField {
            id: passwordField
            Layout.preferredWidth: 150
            placeholderText: "Password"
            echoMode: TextInput.Password
            enabled: !ConnectionManager.connected
        }

        ToolButton {
            text: ConnectionManager.connected ? "Disconnect" : "Connect"
            flat: false
            highlighted: true

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

        Rectangle {
            width: 12
            height: 12
            radius: 6
            color: ConnectionManager.authenticated ? Material.color(Material.Green) :
                   ConnectionManager.connected ? Material.color(Material.Amber) :
                   Material.color(Material.Red)
        }
    }
}
