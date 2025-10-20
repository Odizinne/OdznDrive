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
    signal previewClicked()

    property bool shareEnabled: true
    property bool showPreview: !itemIsDir && (Utils.isImageFile(itemName) || Utils.isEditableTextFile(itemName))

    MenuItem {
        text: contextMenu.itemName
        enabled: false
        font.bold: true
    }

    MenuItem {
        text: Utils.isImageFile(contextMenu.itemName) ? "Preview" : "Edit"
        visible: contextMenu.showPreview
        height: contextMenu.showPreview ? implicitHeight : 0
        icon.source: Utils.isImageFile(contextMenu.itemName) ? "qrc:/icons/types/picture.svg" : "qrc:/icons/types/text.svg"
        icon.width: 16
        icon.height: 16
        onClicked: contextMenu.previewClicked()
    }

    MenuSeparator {}

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
