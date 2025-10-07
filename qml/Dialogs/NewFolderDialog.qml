import QtQuick.Controls.Material
import QtQuick.Layouts
import Odizinne.OdznDrive
import QtQuick

CustomDialog {
    id: newFolderDialog
    title: "Create New Folder"
    width: 300
    parent: Overlay.overlay

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        TextField {
            id: folderNameField
            Layout.fillWidth: true
            Layout.preferredHeight: 35
            placeholderText: "Enter folder name"
            onAccepted: newFolderDialog.accepted()
        }
    }

    standardButtons: Dialog.Ok | Dialog.Cancel

    onAccepted: {
        if (folderNameField.text.trim() !== "") {
            let newPath = FileModel.currentPath
            if (newPath && !newPath.endsWith('/')) {
                newPath += '/'
            }
            newPath += folderNameField.text.trim()
            ConnectionManager.createDirectory(newPath)
            folderNameField.clear()
            newFolderDialog.close()
        }
    }

    onOpened: {
        folderNameField.forceActiveFocus()
    }

    onRejected: {
        folderNameField.clear()
    }
}
