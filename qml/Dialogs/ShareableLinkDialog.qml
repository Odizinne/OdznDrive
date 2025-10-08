import QtQuick.Controls.Material
import QtQuick.Layouts
import QtQuick
import Odizinne.OdznDrive

CustomDialog {
    id: dialog
    title: "Link is ready"
    standardButtons: Dialog.Close
    property string shareableLink: ""
    RowLayout {
        anchors.fill: parent

        TextField {
            id: textField
            Layout.topMargin: 20
            Layout.preferredHeight: 35
            Layout.fillWidth: true
            readOnly: true
            text: dialog.shareableLink
        }

        CustomButton {
            Layout.topMargin: 20
            icon.width: 24
            icon.height: 24
            icon.source: "qrc:/icons/clipboard.svg"
            onClicked: {
                textField.selectAll()
                textField.copy()
                textField.deselect()
                toolTipTimer.start()
            }
            ToolTip.visible: toolTipTimer.running
            ToolTip.text: "Copied to clipboard"

            Timer {
                id: toolTipTimer
                running: false
                interval: 2000
            }
        }
    }
}
