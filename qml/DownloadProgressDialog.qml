import QtQuick.Controls.Material
import QtQuick.Layouts
import Odizinne.OdznDrive

CustomDialog {
    id: downloadProgressDialog
    title: ConnectionManager.isZipping ? "Compressing Folder" : "Downloading File"
    closePolicy: Popup.NoAutoClose
    standardButtons: Dialog.Cancel

    property int progress: 0

    onRejected: {
        ConnectionManager.cancelDownload()
    }

    ColumnLayout {
        spacing: 15

        Label {
            text: ConnectionManager.currentDownloadFileName || "Preparing download..."
            font.bold: true
        }

        ProgressBar {
            Layout.preferredWidth: 350
            Layout.fillWidth: true
            indeterminate: ConnectionManager.isZipping
            value: ConnectionManager.isZipping ? 0 : (downloadProgressDialog.progress / 100)
        }

        Label {
            text: ConnectionManager.isZipping ? "Compressing..." : downloadProgressDialog.progress + "%"
            Layout.alignment: Qt.AlignHCenter
        }
    }
}
