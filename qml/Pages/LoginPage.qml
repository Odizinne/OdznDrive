pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Material
import QtQuick.Controls.Material.impl
import QtQuick.Layouts
import Odizinne.OdznDrive

Page {
    id: loginPage
    Material.background: Constants.backgroundColor
    signal loginComplete()
    property bool animEnabled: true

    function setLoginToServer() {
        animEnabled = false
        loginContent.opacity = 0
        busyContainer.opacity = 1
        animEnabled = true
    }

    function resetAnimation() {
        animEnabled = false
        art.opacity = 0
        art.scale = 0.5
        art.rotation = -90
        animEnabled = true
    }

    function playAnimation() {
        art.scale = 1
        art.opacity = 1
        art.rotation = 0
    }

    function reset() {
        loginPage.animEnabled = false
        statusLabel.text = "Connecting..."
        loginContent.opacity = 1
        busyContainer.opacity = 0
        loginPage.animEnabled = true
    }

    function focusNextOrConnect() {
        if (urlField.text.trim() === "") {
            urlField.forceActiveFocus()
        } else if (usernameField.text.trim() === "") {
            usernameField.forceActiveFocus()
        } else if (passwordField.text.trim() === "") {
            passwordField.forceActiveFocus()
        } else {
            connectButton.clicked()
        }
    }

    Connections {
        target: ConnectionManager

        function onConnectedChanged() {
            if (!ConnectionManager.connected) {
                busyIndicator.reset()
                // Reset the UI back to login form
                loginPage.animEnabled = false
                busyContainer.opacity = 0
                loginContent.opacity = 1
                loginPage.animEnabled = true
            }
        }

        function onErrorOccurred(error) {
            busyIndicator.reset()
            loginPage.animEnabled = false
            busyContainer.opacity = 0
            loginContent.opacity = 1
            loginPage.animEnabled = true
        }

        function onAuthenticatedChanged() {
            if (ConnectionManager.authenticated) {
                busyIndicator.startFilling()
            } else if (!ConnectionManager.connected) {
                busyIndicator.reset()
                loginPage.animEnabled = false
                busyContainer.opacity = 0
                loginContent.opacity = 1
                loginPage.animEnabled = true
            }
        }
    }

    ListModel {
        id: bubbleModel
        ListElement { size: 400; offsetX: -171; offsetY: -322; colorIndex: 0 }
        ListElement { size: 325; offsetX: -326; offsetY: -138; colorIndex: 2 }
        ListElement { size: 250; offsetX: -2;   offsetY: 46;  colorIndex: 1 }
    }

    LoginArt {
        id: art
        anchors.fill: parent
        model: bubbleModel
        opacity: 0
        scale: 0.5
        rotation: -90

        Component.onCompleted: {
            loginPage.playAnimation()
        }

        Behavior on opacity {
            enabled: loginPage.animEnabled
            NumberAnimation { duration: 1400; easing.type: Easing.OutExpo }
        }

        Behavior on scale {
            enabled: loginPage.animEnabled
            NumberAnimation { duration: 1400; easing.type: Easing.OutExpo }
        }
        Behavior on rotation {
            enabled: loginPage.animEnabled
            NumberAnimation { duration: 1400; easing.type: Easing.OutExpo }
        }
    }

    ColumnLayout {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 10
        spacing: 3
        Label {
            font.pixelSize: 11
            opacity: 0.5
            Layout.alignment: Qt.AlignRight
            text: "Qt " + VersionHelper.getQtVersion()
        }
        Label {
            font.pixelSize: 11
            opacity: 0.5
            Layout.alignment: Qt.AlignRight
            text: VersionHelper.getBuildTimestamp()
        }
        Label {
            font.pixelSize: 11
            opacity: 0.5
            Layout.alignment: Qt.AlignRight
            text: VersionHelper.getApplicationVersion() + "-" + VersionHelper.getCommitSha()
        }
    }

    Rectangle {
        visible: true
        id: loginCard
        anchors.centerIn: parent
        width: 400
        height: loginContent.implicitHeight + 60
        color: Constants.surfaceColor
        radius: 4
        layer.enabled: true
        layer.effect: RoundedElevationEffect {
            elevation: 8
            roundedScale: 4
        }

        ColumnLayout {
            id: loginContent
            anchors.fill: parent
            anchors.margins: 30
            spacing: 20
            opacity: 1
            visible: opacity !== 0.0

            Behavior on opacity {
                enabled: loginPage.animEnabled
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.InOutQuad
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 15

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignCenter
                    spacing: 8
                    Layout.bottomMargin: 20

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

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    TextField {
                        id: urlField
                        Layout.fillWidth: true
                        Layout.preferredHeight: 45
                        placeholderText: "ws://localhost:8888"
                        text: UserSettings.serverUrl
                        font.pixelSize: 14
                        Material.roundedScale: Material.ExtraSmallScale
                        onTextChanged: UserSettings.serverUrl = text.trim()
                        onAccepted: loginPage.focusNextOrConnect()
                        Keys.onReturnPressed: loginPage.focusNextOrConnect()
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    TextField {
                        id: usernameField
                        Layout.fillWidth: true
                        Layout.preferredHeight: 45
                        placeholderText: "Username"
                        text: UserSettings.serverUsername
                        font.pixelSize: 14
                        Material.roundedScale: Material.ExtraSmallScale
                        onTextChanged: UserSettings.serverUsername = text.trim()
                        onAccepted: loginPage.focusNextOrConnect()
                        Keys.onReturnPressed: loginPage.focusNextOrConnect()
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5

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
                        onAccepted: loginPage.focusNextOrConnect()
                        Keys.onReturnPressed: loginPage.focusNextOrConnect()
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    TapHandler {
                        onTapped: showPasswordCheckbox.click()
                    }

                    Label {
                        text: "Show password"
                        Layout.fillWidth: true
                        font.pixelSize: 13
                    }

                    CheckBox {
                        id: showPasswordCheckbox
                        checked: passwordField.echoMode === TextInput.Normal
                        onClicked: checked ? passwordField.echoMode = TextInput.Normal : passwordField.echoMode = TextInput.Password
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: -15
                    TapHandler {
                        onTapped: autoconnectCheckbox.click()
                    }

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
                    enabled: urlField.text.trim() !== "" &&
                             usernameField.text.trim() !== "" &&
                             passwordField.text.trim() !== ""

                    onClicked: {
                        if (urlField.text.trim() !== "" &&
                            usernameField.text.trim() !== "" &&
                            passwordField.text.trim() !== "") {
                            loginContent.opacity = 0
                            busyContainer.opacity = 1
                            ConnectionManager.connectToServer(
                                urlField.text.trim(),
                                usernameField.text.trim(),
                                passwordField.text.trim()
                                )
                        }
                    }

                    background: Rectangle {
                        implicitHeight: connectButton.Material.buttonHeight
                        radius: connectButton.Material.roundedScale

                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop {
                                position: 0.0
                                color: Constants.headerGradientStart
                            }
                            GradientStop {
                                position: 1.0
                                color: Constants.headerGradientStop
                            }
                        }

                        // Overlay for hover/press states
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: connectButton.down ? "black" : "white"
                            opacity: connectButton.enabled ?
                                         (connectButton.down ? 0.2 : connectButton.hovered ? 0.1 : 0) :
                                         0

                            Behavior on opacity {
                                NumberAnimation { duration: 150 }
                            }
                        }

                        // Disabled state overlay
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: Constants.borderColor
                            opacity: connectButton.enabled ? 0 : 1

                            Behavior on opacity {
                                NumberAnimation { duration: 150 }
                            }
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
                        color: "black"
                        opacity: connectButton.enabled ? 1.0 : 0.5
                    }
                }
            }
        }

        Item {
            id: busyContainer
            anchors.fill: parent
            opacity: 0
            visible: opacity !== 0.0

            Behavior on opacity {
                enabled: loginPage.animEnabled
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.InOutQuad
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 20

                Image {
                    source: "qrc:/icons/icon.png"
                    sourceSize.width: 64
                    sourceSize.height: 64
                    Layout.bottomMargin: 25
                    Layout.alignment: Qt.AlignHCenter
                }

                CustomBusyIndicator {
                    id: busyIndicator
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 200
                    Layout.preferredHeight: 8

                    onComplete: {
                        viewTransitionTimer.start()
                    }
                }

                Label {
                    id: statusLabel
                    Layout.alignment: Qt.AlignHCenter
                    text: "Connecting..."
                    font.pixelSize: 14
                    opacity: 0.7

                    Connections {
                        target: ConnectionManager
                        function onAuthenticatedChanged() {
                            fadeOut.start()
                        }
                    }

                    SequentialAnimation {
                        id: fadeOut
                        NumberAnimation {
                            target: statusLabel
                            property: "opacity"
                            to: 0
                            duration: 250
                            easing.type: Easing.InQuad
                        }
                        ScriptAction {
                            script: statusLabel.text = ConnectionManager.authenticated ? "Connected!" : "Connecting..."
                        }
                        NumberAnimation {
                            target: statusLabel
                            property: "opacity"
                            to: 0.7
                            duration: 250
                            easing.type: Easing.OutQuad
                        }
                    }
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
        } else if (usernameField.text.trim() === "") {
            usernameField.forceActiveFocus()
        } else if (passwordField.text.trim() === "") {
            passwordField.forceActiveFocus()
        }
    }
}
