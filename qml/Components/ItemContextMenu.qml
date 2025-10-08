import QtQuick.Controls.Material
import Odizinne.OdznDrive

CustomMenu {
    id: contextMenu
    width: 200

    required property string itemPath
    required property string itemName
    required property bool itemIsDir

    signal downloadCLicked()
    signal renameClicked()
    signal deleteClicked()
    signal shareClicked()

    property bool shareEnabled: true

    MenuItem {
        text: contextMenu.itemName
        enabled: false
        font.bold: true
    }

    MenuItem {
        text: "Share"
        enabled: contextMenu.shareEnabled
        icon.source: "qrc:/icons/link.svg"
        icon.width: 16
        icon.height: 16
        onClicked: contextMenu.shareClicked()
    }

    MenuSeparator {}

    MenuItem {
        text: "Download"
        icon.source: "qrc:/icons/download.svg"
        icon.width: 16
        icon.height: 16
        onClicked: contextMenu.downloadCLicked()
    }

    MenuItem {
        text: "Rename"
        icon.source: "qrc:/icons/rename.svg"
        icon.width: 16
        icon.height: 16
        onClicked: contextMenu.renameClicked()
    }

    MenuItem {
        text: "Delete"
        icon.source: "qrc:/icons/delete.svg"
        icon.width: 16
        icon.height: 16
        onClicked: contextMenu.deleteClicked()
    }
}
