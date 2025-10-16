import QtQuick
import QtQuick.Controls.Material
import QtQuick.Layouts
import Odizinne.OdznDrive

CustomDialog {
    id: imagePreviewDialog
    title: fileName
    parent: Overlay.overlay
    modal: true

    property string filePath: ""
    property string fileName: ""
    property bool isDownloading: false
    property string tempLocalPath: ""
    property string imageSource: ""

    Connections {
        target: ConnectionManager
        function onDownloadComplete(path) {
            if (path === imagePreviewDialog.tempLocalPath && imagePreviewDialog.visible && imagePreviewDialog.isDownloading) {
                imagePreviewDialog.isDownloading = false
                imagePreviewDialog.imageSource = "file:///" + path
            }
        }
        function onErrorOccurred(error) {
            // Handle any download errors
            if (imagePreviewDialog.visible && imagePreviewDialog.isDownloading) {
                imagePreviewDialog.isDownloading = false
            }
        }
    }

    onAboutToShow: {
        isDownloading = true
        imageSource = ""
        tempLocalPath = FileDialogHelper.getTempFilePath(fileName)
        // Download full image to temp location
        ConnectionManager.downloadFile(filePath, tempLocalPath)
    }

    onClosed: {
        // Clean up temp file
        if (tempLocalPath !== "") {
            FileDialogHelper.deleteFile(tempLocalPath)
            tempLocalPath = ""
        }
    }

    ColumnLayout {
        anchors.fill: parent

        BusyIndicator {
            Layout.alignment: Qt.AlignCenter
            visible: imagePreviewDialog.isDownloading
            running: imagePreviewDialog.isDownloading
            Material.accent: Constants.headerGradientStart
        }

        Image {
            id: previewImage
            Layout.fillWidth: true
            Layout.fillHeight: true
            source: imagePreviewDialog.imageSource
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            cache: false
            smooth: true
            visible: !imagePreviewDialog.isDownloading

            onStatusChanged: {
                if (status === Image.Ready) {
                    imagePreviewDialog.isDownloading = false
                } else if (status === Image.Error) {
                    imagePreviewDialog.isDownloading = false
                }
            }
        }

        Label {
            Layout.alignment: Qt.AlignCenter
            text: "Failed to load image"
            visible: !imagePreviewDialog.isDownloading && previewImage.status === Image.Error
            opacity: 0.5
        }
    }

    footer: DialogButtonBox {
        Button {
            flat: true
            text: "Close"
            onClicked: imagePreviewDialog.close()
        }
    }
}
