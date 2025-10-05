import QtQuick
import QtQuick.Controls.Material
import QtQuick.Controls.Material.impl
import QtQuick.Layouts
import Odizinne.OdznDrive

Page {
    id: loginPage
    Material.background: Constants.backgroundColor
    signal loginComplete()

    Connections {
        target: ConnectionManager

        function onConnectedChanged() {
            if (ConnectionManager.connected) {
                busyIndicator.startFilling()
            } else {
                busyIndicator.reset()
                loginContent.opacity = 1
                busyContainer.opacity = 0
            }
        }

        function onAuthenticatedChanged() {
            if (!ConnectionManager.authenticated && !ConnectionManager.connected) {
                busyIndicator.reset()
                loginContent.opacity = 1
                busyContainer.opacity = 0
            }
        }
    }

    Rectangle {
        id: loginCard
        anchors.centerIn: parent
        width: 400
        height: loginContent.implicitHeight + 60
        color: Constants.surfaceColor
        radius: 8

        layer.enabled: true
        layer.effect: RoundedElevationEffect {
            elevation: 12
            roundedScale: 8
        }

        ColumnLayout {
            id: loginContent
            anchors.fill: parent
            anchors.margins: 30
            spacing: 20
            opacity: 1

            Behavior on opacity {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.InOutQuad
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 80

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 8

                    Image {
                        Layout.alignment: Qt.AlignHCenter
                        source: "qrc:/icons/icon.png"
                        sourceSize.width: 48
                        sourceSize.height: 48
                    }

                    Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: "OdznDrive"
                        font.pixelSize: 28
                        font.bold: true
                    }

                    Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Connect to your server"
                        opacity: 0.7
                        font.pixelSize: 13
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 15

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    Label {
                        text: "Server URL"
                        font.pixelSize: 13
                        opacity: 0.9
                    }

                    TextField {
                        id: urlField
                        Layout.fillWidth: true
                        Layout.preferredHeight: 45
                        placeholderText: "ws://localhost:8888"
                        text: UserSettings.serverUrl
                        font.pixelSize: 14
                        Material.roundedScale: Material.ExtraSmallScale

                        onTextChanged: UserSettings.serverUrl = text.trim()
                        onAccepted: passwordField.forceActiveFocus()

                        Keys.onReturnPressed: passwordField.forceActiveFocus()
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    Label {
                        text: "Password"
                        font.pixelSize: 13
                        opacity: 0.9
                    }

                    TextField {
                        id: passwordField
                        Layout.fillWidth: true
                        Layout.preferredHeight: 45
                        placeholderText: "Enter password"
                        text: UserSettings.serverPassword
                        echoMode: TextInput.Password
                        font.pixelSize: 14
                        Material.roundedScale: Material.ExtraSmallScale

                        onTextChanged: UserSettings.serverPassword = text.trim()
                        onAccepted: connectButton.clicked()

                        Keys.onReturnPressed: connectButton.clicked()
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 5

                    Label {
                        text: "Connect automatically on startup"
                        Layout.fillWidth: true
                        font.pixelSize: 13
                    }

                    CheckBox {
                        id: autoconnectCheckbox
                        checked: UserSettings.autoconnect
                        onClicked: UserSettings.autoconnect = checked
                    }
                }

                Button {
                    id: connectButton
                    Layout.fillWidth: true
                    Layout.preferredHeight: 45
                    Layout.topMargin: 10
                    text: "Connect"
                    font.pixelSize: 14
                    font.bold: true
                    Material.roundedScale: Material.ExtraSmallScale
                    enabled: urlField.text.trim() !== "" && passwordField.text.trim() !== ""

                    onClicked: {
                        if (urlField.text.trim() !== "" && passwordField.text.trim() !== "") {
                            loginContent.opacity = 0
                            busyContainer.opacity = 1
                            ConnectionManager.connectToServer(urlField.text.trim(), passwordField.text.trim())
                        }
                    }

                    background: Rectangle {
                        implicitHeight: connectButton.Material.buttonHeight
                        radius: connectButton.Material.roundedScale
                        color: connectButton.enabled ?
                                   (connectButton.down ? Qt.darker(Material.primary, 1.2) :
                                    connectButton.hovered ? Qt.lighter(Material.primary, 1.1) :
                                    Material.primary) :
                                   Constants.borderColor

                        Behavior on color {
                            ColorAnimation { duration: 150 }
                        }

                        layer.enabled: connectButton.enabled
                        layer.effect: RoundedElevationEffect {
                            elevation: connectButton.down ? 8 : 2
                            roundedScale: Material.ExtraSmallScale
                        }
                    }

                    contentItem: Label {
                        text: connectButton.text
                        font: connectButton.font
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        color: connectButton.enabled ? "white" : Material.foreground
                        opacity: connectButton.enabled ? 1.0 : 0.5
                    }
                }
            }
        }

        Item {
            id: busyContainer
            anchors.fill: parent
            opacity: 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.InOutQuad
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 20

                CustomBusyIndicator {
                    id: busyIndicator
                    Layout.alignment: Qt.AlignHCenter
                    width: 80
                    height: 80

                    onFillComplete: {
                        viewTransitionTimer.start()
                    }
                }

                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: busyIndicator.filling ? "Connected!" : "Connecting..."
                    font.pixelSize: 14
                    opacity: 0.7
                }
            }

            Timer {
                id: viewTransitionTimer
                interval: 1500
                repeat: false
                onTriggered: {
                    loginPage.loginComplete()
                }
            }
        }
    }

    Component.onCompleted: {
        if (urlField.text.trim() === "") {
            urlField.forceActiveFocus()
        } else if (passwordField.text.trim() === "") {
            passwordField.forceActiveFocus()
        }
    }
}
