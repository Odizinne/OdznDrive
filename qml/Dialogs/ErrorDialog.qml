import QtQuick.Controls.Material
import Odizinne.OdznDrive

CustomDialog {
    title: "Error"
    width: 300
    property alias text: errorLabel.text
    Label {
        anchors.fill: parent
        id: errorLabel
    }
    standardButtons: Dialog.Ok
}
