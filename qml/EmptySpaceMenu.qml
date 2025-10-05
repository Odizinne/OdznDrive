import QtQuick.Controls.Material

CustomMenu {
    id: menu
    width: 200

    signal newFolderClicked()
    signal uploadFilesClicked()
    signal refreshClicked()
    MenuItem {
        text: "New Folder"
        icon.source: "qrc:/icons/plus.svg"
        icon.width: 16
        icon.height: 16
        enabled: ConnectionManager.authenticated
        onClicked: menu.newFolderClicked()
    }

    MenuItem {
        text: "Upload Files"
        icon.source: "qrc:/icons/upload.svg"
        icon.width: 16
        icon.height: 16
        enabled: ConnectionManager.authenticated
        onClicked: menu.uploadFilesClicked()
    }

    MenuItem {
        text: "Refresh"
        icon.source: "qrc:/icons/refresh.svg"
        icon.width: 16
        icon.height: 16
        enabled: ConnectionManager.authenticated
        onClicked: menu.refreshClicked()
    }
}
