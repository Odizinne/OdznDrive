import QtQuick.Controls.Material
import QtQuick.Layouts
import QtQuick
import Odizinne.OdznDrive

CustomMenu {
    id: menu

    MenuItem {
        Layout.fillWidth: true
        text: ConnectionManager.serverName
        enabled: false
    }

    MenuItem {
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

    MenuItem {
        text: "Advanced settings"
        onClicked: Utils.showAdvancedSettingsDialog()
        Layout.fillWidth: true
    }

    MenuItem {
        Layout.fillWidth: true
        text: "Folders first"
        checked: UserSettings.foldersFirst
        checkable: true
        onClicked: UserSettings.foldersFirst = checked
    }

    MenuItem {
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

    MenuItem {
        Layout.fillWidth: true
        text: "Disconnect"
        onClicked: {
            menu.close()
            ConnectionManager.disconnect()
        }
    }

    MenuItem {
        Layout.fillWidth: true
        text: "Exit"
        onClicked: Qt.quit()
    }
}

