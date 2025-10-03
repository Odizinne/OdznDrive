import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Odizinne.OdznDriveClient

Rectangle {
    id: root
    color: "#2196F3"
    
    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10
        
        Label {
            text: "OdznDrive"
            font.pixelSize: 20
            font.bold: true
            color: "white"
        }
        
        Item {
            Layout.fillWidth: true
        }
        
        Label {
            text: "Server URL:"
            color: "white"
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
            color: "white"
        }
        
        TextField {
            id: passwordField
            Layout.preferredWidth: 150
            placeholderText: "Password"
            echoMode: TextInput.Password
            enabled: !ConnectionManager.connected
        }
        
        Button {
            text: ConnectionManager.connected ? "Disconnect" : "Connect"
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
            color: ConnectionManager.authenticated ? "#4CAF50" : 
                   ConnectionManager.connected ? "#FFC107" : "#F44336"
        }
    }
}