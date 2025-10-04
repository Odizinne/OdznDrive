import QtQuick.Controls.Material
import QtQuick.Layouts
import Odizinne.OdznDrive
import QtQuick

CustomDialog {
    id: multiDeleteConfirmDialog
    title: "Confirm Delete"
    property int itemCount: 0
    parent: Overlay.overlay

    Label {
        text: "Are you sure you want to delete " + multiDeleteConfirmDialog.itemCount + " item(s)?"
    }

    standardButtons: Dialog.Yes | Dialog.No

    onAccepted: {
        let paths = root.getCheckedPaths()
        ConnectionManager.deleteMultiple(paths)
        root.uncheckAll()
    }
}
