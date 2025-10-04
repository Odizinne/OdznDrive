import QtQuick.Controls.Material
import QtQuick.Layouts
import Odizinne.OdznDrive

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
        spacing: 15

        Label {
            text: ConnectionManager.currentUploadFileName || "Preparing upload..."
            font.bold: true
        }

        Label {
            text: ConnectionManager.uploadQueueSize > 0 ?
                      `${ConnectionManager.uploadQueueSize} file(s) remaining in queue` :
                      "Upload in progress..."
            visible: ConnectionManager.uploadQueueSize > 0
            opacity: 0.7
        }

        ProgressBar {
            Layout.preferredWidth: 350
            Layout.fillWidth: true
            value: uploadProgressDialog.progress / 100
        }

        Label {
            text: uploadProgressDialog.progress + "%"
            Layout.alignment: Qt.AlignHCenter
        }
    }
}
