import QtQuick.Controls.Material
import QtQuick.Controls.Material.impl
import QtQuick.Layouts
import QtQuick
import Odizinne.OdznDrive

Rectangle {
    id: menu
    color: Constants.altBackgroundColor
    clip: true
    bottomLeftRadius: 4
    bottomRightRadius: 4
    visible: menuHeight !== 0
    layer.enabled: visible
    layer.effect: RoundedElevationEffect {
        elevation: 3
        roundedScale: 0
    }

    property int menuHeight: opened ? menuLyt.implicitHeight : 0
    property bool opened: false

    Behavior on menuHeight {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutQuad
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutQuad
        }
    }

    function open() {
        opened = true
    }

    function close() {
        opened = false
    }

    ColumnLayout {
        id: menuLyt
        opacity: menu.menuHeight > 0 ? 1 : 0
        anchors.fill: parent
        spacing: 0

        Behavior on opacity {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutQuad
            }
        }

        ItemDelegate {
            Layout.fillWidth: true
            text: ConnectionManager.serverName
            enabled: false
        }

        ItemDelegate {
            Layout.fillWidth: true
            text: "Users managment"
            implicitHeight: ConnectionManager.isAdmin ? Math.max(implicitBackgroundHeight + topInset + bottomInset,
                                                                 implicitContentHeight + topPadding + bottomPadding,
                                                                 implicitIndicatorHeight + topPadding + bottomPadding) : 0
            enabled: ConnectionManager.isAdmin
            visible: ConnectionManager.isAdmin
            onClicked: Utils.showUserManagmentDialog()
        }

        MenuSeparator {
            Layout.fillWidth: true
        }

        ItemDelegate {
            text: "Advanced settings"
            onClicked: Utils.showAdvancedSettingsDialog()
            Layout.fillWidth: true
        }

        SwitchDelegate {
            Layout.fillWidth: true
            text: "Folders first"
            checked: UserSettings.foldersFirst
            checkable: true
            onClicked: UserSettings.foldersFirst = checked
        }

        SwitchDelegate {
            Layout.fillWidth: true
            text: "Dark mode"
            checkable: true
            checked: UserSettings.darkMode
            onClicked: {
                UserSettings.darkMode = checked
                WindowsPlatform.setTitlebarColor(checked)
            }
        }

        MenuSeparator {
            Layout.fillWidth: true
        }

        ItemDelegate {
            Layout.fillWidth: true
            text: "Disconnect"
            onClicked: {
                menu.close()
                ConnectionManager.disconnect()
            }
        }

        ItemDelegate {
            Layout.fillWidth: true
            text: "Exit"
            onClicked: Qt.quit()
        }
    }
}
