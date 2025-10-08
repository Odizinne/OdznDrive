import QtQuick.Controls.Material
import QtQuick.Layouts
import Odizinne.OdznDrive
import QtQuick

CustomDialog {
    id: newFolderDialog
    title: "Create New Folder"
    width: 300
    parent: Overlay.overlay

    property bool correctName: {
        let invalidChars = /[<>:"/\\|?*\x00-\x1F]/
        return !invalidChars.test(folderNameField.text) && !folderNameField.text.includes("/")
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        TextField {
            id: folderNameField
            Layout.fillWidth: true
            Layout.preferredHeight: 35
            placeholderText: "Enter folder name"
            onAccepted: {
                if (newFolderDialog.correctName) newFolderDialog.accepted()
            }
        }

        Label {
            id: errorLabel
            text: "Invalid characters detected"
            color: Material.color(Material.Red)
            font.pixelSize: 12
            visible: !newFolderDialog.correctName
            opacity: 0.7
        }
    }

    onAccepted: {
        let newPath = FileModel.currentPath
        if (newPath && !newPath.endsWith('/')) newPath += '/'
        newPath += folderNameField.text.trim()
        ConnectionManager.createDirectory(newPath)
        folderNameField.clear()
        newFolderDialog.close()
    }

    onOpened: folderNameField.forceActiveFocus()
    onRejected: folderNameField.clear()

    footer: DialogButtonBox {
        Button {
            flat: true
            text: "Cancel"
            onClicked: {
                newFolderDialog.reject()
                newFolderDialog.close()
            }
        }

        Button {
            flat: true
            text: "Ok"
            enabled: folderNameField.text !== "" && newFolderDialog.correctName
            onClicked: newFolderDialog.accept()
        }
    }
}

