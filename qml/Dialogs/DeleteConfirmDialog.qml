import QtQuick.Controls.Material
import Odizinne.OdznDrive
import QtQuick

CustomDialog {
    id: deleteConfirmDialog
    title: "Confirm Delete"
    property string itemPath: ""
    property bool isDirectory: false
    parent: Overlay.overlay

    Label {
        text: "Are you sure you want to delete this " +
              (deleteConfirmDialog.isDirectory ? "folder" : "file") + "?"
    }

    standardButtons: Dialog.Yes | Dialog.No

    onAccepted: {
        if (isDirectory) {
            ConnectionManager.deleteDirectory(itemPath)
        } else {
            ConnectionManager.deleteFile(itemPath)
        }
    }
}
