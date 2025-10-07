import QtQuick.Controls.Material
import QtQuick.Layouts
import Odizinne.OdznDrive
import QtQuick

CustomDialog {
    id: uploadProgressDialog
    title: "Uploading Files"
    closePolicy: Popup.NoAutoClose
    standardButtons: Dialog.Cancel
    property int progress: 0

    onRejected: {
        ConnectionManager.cancelAllUploads()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 15

        RowLayout {
            Label {
                text: ConnectionManager.currentUploadFileName || "Preparing upload..."
                font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Label {
                text: uploadProgressDialog.progress + "%"
                Layout.alignment: Qt.AlignHCenter
            }
        }

        Label {
            text: ConnectionManager.uploadQueueSize > 0 ?
                      `${ConnectionManager.uploadQueueSize} file(s) remaining in queue` :
                      "Upload in progress..."
            visible: ConnectionManager.uploadQueueSize > 0
            opacity: 0.7
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        CustomProgressBar {
            Layout.preferredWidth: 350
            Layout.fillWidth: true
            value: uploadProgressDialog.progress / 100
        }

        TransferStatus {
            Layout.alignment: Qt.AlignRight
        }
    }
}
