import QtQuick.Controls.Material
import QtQuick.Layouts
import Odizinne.OdznDrive
import QtQuick

CustomDialog {
    id: renameDialog
    title: "Rename"
    width: 300
    parent: Overlay.overlay

    property string itemPath: ""
    property string itemName: ""

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        TextField {
            id: renameField
            Layout.fillWidth: true
            Layout.preferredHeight: 35
            placeholderText: "Enter new name"
            onAccepted: renameDialog.accepted()
        }
    }

    standardButtons: Dialog.Ok | Dialog.Cancel

    onAccepted: {
        if (renameField.text.trim() !== "") {
            ConnectionManager.renameItem(itemPath, renameField.text.trim())
        }
    }

    onAboutToShow: {
        renameField.text = itemName
        renameField.selectAll()
        renameField.forceActiveFocus()
    }

    onRejected: {
        renameField.clear()
    }
}
