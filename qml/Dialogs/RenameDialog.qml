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
    property bool correctName: {
        let invalidChars = /[<>:"/\\|?*\x00-\x1F]/
        return !invalidChars.test(renameField.text) && !renameField.text.includes("/")
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        TextField {
            id: renameField
            Layout.fillWidth: true
            Layout.preferredHeight: 35
            placeholderText: "Enter new name"
            onAccepted: {
                if (renameDialog.correctName) renameDialog.accepted()
            }
        }

        Label {
            id: errorLabel
            text: "Invalid characters detected"
            color: Material.color(Material.Red)
            font.pixelSize: 12
            visible: !renameDialog.correctName
            opacity: 0.7
        }
    }

    footer: DialogButtonBox {
        Button {
            flat: true
            text: "Cancel"
            onClicked: {
                renameDialog.reject()
                renameDialog.close()
            }
        }

        Button {
            flat: true
            text: "Ok"
            enabled: renameField.text !== "" && renameDialog.correctName
            onClicked: renameDialog.accept()
        }
    }

    onAccepted: {
        ConnectionManager.renameItem(itemPath, renameField.text.trim())
        renameField.clear()
        renameDialog.close()
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
