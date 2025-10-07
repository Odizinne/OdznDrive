import QtQuick.Controls.Material
import Odizinne.OdznDrive
import QtQuick

CustomDialog {
    id: multiDeleteConfirmDialog
    title: "Confirm Delete"
    property int itemCount: 0
    parent: Overlay.overlay

    Label {
        anchors.fill: parent
        wrapMode: Text.WordWrap
        text: "Are you sure you want to delete " + multiDeleteConfirmDialog.itemCount + " item(s)?"
    }

    standardButtons: Dialog.Yes | Dialog.No

    onAccepted: {
        let paths = Utils.getCheckedPaths()
        ConnectionManager.deleteMultiple(paths)
        Utils.uncheckAll()
    }
}
