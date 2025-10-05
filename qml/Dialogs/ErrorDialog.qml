import QtQuick.Controls.Material
import Odizinne.OdznDrive
import QtQuick

CustomDialog {
    title: "Error"
    width: 300
    property alias text: errorLabel.text
    Label {
        anchors.fill: parent
        id: errorLabel
        wrapMode: Text.WordWrap
    }
    standardButtons: Dialog.Ok
}
