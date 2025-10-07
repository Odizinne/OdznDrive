import QtQuick.Controls.Material
import QtQuick
import Odizinne.OdznDrive

CustomDialog {
    id: confirmDeleteUserDialog
    width: 300
    title: "Delete " + confirmDeleteUserDialog.username + "?"
    property string username: ""
    standardButtons: Dialog.Cancel | Dialog.Yes

    Label {
        anchors.fill: parent
        text: "This action cannot be undone"
        wrapMode: Text.WordWrap
    }

    onAccepted: ConnectionManager.deleteUser(username)
}
