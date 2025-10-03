import QtQuick
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtQuick.Dialogs
import Odizinne.OdznDriveClient

ApplicationWindow {
    id: root
    visible: true
    width: 1000
    height: 700
    title: "OdznDrive Client"

    Material.theme: Constants.materialTheme
    Material.accent: Material.Blue

    color: Constants.backgroundColor

    Connections {
        target: ConnectionManager

        function onAuthenticatedChanged() {
            if (ConnectionManager.authenticated) {
                ConnectionManager.listDirectory("")
                ConnectionManager.getStorageInfo()
            }
        }

        function onDirectoryListed(path, files) {
            FileModel.loadDirectory(path, files)
        }

        function onErrorOccurred(error) {
            uploadProgressDialog.close()
            if (error !== "Upload cancelled by user") {
                errorDialog.text = error
                errorDialog.open()
            }
        }

        function onUploadProgress(progress) {
            uploadProgressDialog.progress = progress
            uploadProgressDialog.open()

            let queueText = ConnectionManager.uploadQueueSize > 0 ?
                ` (${ConnectionManager.uploadQueueSize} in queue)` : ""
            statusLabel.text = `Uploading: ${progress}%${queueText}`
        }

        function onUploadComplete(path) {
            // Don't close dialog if there are more uploads in queue
            if (ConnectionManager.uploadQueueSize === 0) {
                uploadProgressDialog.close()
                statusLabel.text = "All uploads complete"
            }
            ConnectionManager.listDirectory(FileModel.currentPath)
            storageUpdateTimer.restart()
        }

        function onDownloadProgress(progress) {
            statusLabel.text = `Downloading: ${progress}%`
        }

        function onDownloadComplete(path) {
            statusLabel.text = "Download complete: " + path
        }

        function onDirectoryCreated(path) {
            ConnectionManager.listDirectory(FileModel.currentPath)
        }

        function onFileDeleted(path) {
            ConnectionManager.listDirectory(FileModel.currentPath)
            storageUpdateTimer.restart()
        }

        function onDirectoryDeleted(path) {
            ConnectionManager.listDirectory(FileModel.currentPath)
            storageUpdateTimer.restart()
        }

        function onItemMoved(fromPath, toPath) {
            ConnectionManager.listDirectory(FileModel.currentPath)
            storageUpdateTimer.restart()
        }

        function onStorageInfo(total, used, available) {
            storageBar.value = used / total
            let usedMB = Math.round(used / 1024 / 1024)
            let totalMB = Math.round(total / 1024 / 1024)
            storageLabel.text = `Storage: ${usedMB} MB / ${totalMB} MB`
        }

        function onUploadQueueSizeChanged() {
            if (ConnectionManager.uploadQueueSize === 0 && !ConnectionManager.currentUploadFileName) {
                uploadProgressDialog.close()
            }
        }
    }

    Timer {
        id: storageUpdateTimer
        interval: 500
        repeat: false
        onTriggered: {
            ConnectionManager.getStorageInfo()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        HeaderBar {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            color: Constants.surfaceColor

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 5

                ToolButton {
                    text: "↑"
                    enabled: FileModel.canGoUp && ConnectionManager.authenticated
                    onClicked: {
                        let parentPath = FileModel.getParentPath()
                        ConnectionManager.listDirectory(parentPath)
                    }
                    ToolTip.visible: hovered
                    ToolTip.text: "Go up"
                }

                ToolButton {
                    text: "⟳"
                    enabled: ConnectionManager.authenticated
                    onClicked: {
                        ConnectionManager.listDirectory(FileModel.currentPath)
                    }
                    ToolTip.visible: hovered
                    ToolTip.text: "Refresh"
                }

                ToolButton {
                    text: "+"
                    enabled: ConnectionManager.authenticated
                    onClicked: newFolderDialog.open()
                    ToolTip.visible: hovered
                    ToolTip.text: "New folder"
                }

                ToolButton {
                    text: "↑"
                    enabled: ConnectionManager.authenticated
                    onClicked: uploadDialog.open()
                    ToolTip.visible: hovered
                    ToolTip.text: "Upload files"
                }

                Item {
                    Layout.fillWidth: true
                }

                Label {
                    id: storageLabel
                    text: "Storage: -- / --"
                }

                ProgressBar {
                    id: storageBar
                    Layout.preferredWidth: 150
                    value: 0
                }
            }
        }

        FileListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            color: Constants.surfaceColor

            Label {
                id: statusLabel
                anchors.centerIn: parent
                text: ConnectionManager.statusMessage
            }
        }
    }

    Dialog {
        id: newFolderDialog
        title: "Create New Folder"
        modal: true
        anchors.centerIn: parent

        ColumnLayout {
            spacing: 10

            Label {
                text: "Folder name:"
            }

            TextField {
                id: folderNameField
                Layout.preferredWidth: 300
                placeholderText: "Enter folder name"
            }
        }

        standardButtons: Dialog.Ok | Dialog.Cancel

        onAccepted: {
            if (folderNameField.text.trim() !== "") {
                let newPath = FileModel.currentPath
                if (newPath && !newPath.endsWith('/')) {
                    newPath += '/'
                }
                newPath += folderNameField.text.trim()
                ConnectionManager.createDirectory(newPath)
                folderNameField.clear()
            }
        }

        onRejected: {
            folderNameField.clear()
        }
    }

    FileDialog {
        id: uploadDialog
        fileMode: FileDialog.OpenFiles
        onAccepted: {
            let files = []
            for (let i = 0; i < selectedFiles.length; i++) {
                let fileUrl = selectedFiles[i].toString()

                // Remove file:// prefix to get local path
                let localPath = fileUrl
                if (localPath.startsWith("file://")) {
                    localPath = localPath.substring(7)
                }

                // On Windows, remove leading slash before drive letter (e.g., /C:/ -> C:/)
                if (localPath.match(/^\/[A-Za-z]:\//)) {
                    localPath = localPath.substring(1)
                }

                files.push(localPath)
            }

            if (files.length > 0) {
                ConnectionManager.uploadFiles(files, FileModel.currentPath)
            }
        }
    }

    FileDialog {
        id: downloadDialog
        fileMode: FileDialog.SaveFile
        property string remotePath: ""

        onAccepted: {
            let localPath = selectedFile.toString()

            // Remove file:// prefix to get local path
            if (localPath.startsWith("file://")) {
                localPath = localPath.substring(7)
            }

            // On Windows, remove leading slash before drive letter (e.g., /C:/ -> C:/)
            if (localPath.match(/^\/[A-Za-z]:\//)) {
                localPath = localPath.substring(1)
            }

            ConnectionManager.downloadFile(remotePath, localPath)
        }
    }

    Dialog {
        id: uploadProgressDialog
        title: "Uploading Files"
        modal: true
        closePolicy: Popup.NoAutoClose
        anchors.centerIn: parent

        property int progress: 0

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

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 10

                ToolButton {
                    text: "Cancel Current"
                    flat: false
                    onClicked: {
                        ConnectionManager.cancelUpload()
                    }
                }

                ToolButton {
                    text: "Cancel All"
                    flat: false
                    visible: ConnectionManager.uploadQueueSize > 0
                    onClicked: {
                        ConnectionManager.cancelAllUploads()
                        uploadProgressDialog.close()
                    }
                }
            }
        }
    }

    Dialog {
        id: errorDialog
        title: "Error"
        property alias text: errorLabel.text
        modal: true
        anchors.centerIn: parent

        Label {
            id: errorLabel
        }

        standardButtons: Dialog.Ok
    }

    Dialog {
        id: deleteConfirmDialog
        title: "Confirm Delete"
        property string itemPath: ""
        property bool isDirectory: false
        modal: true
        anchors.centerIn: parent

        Label {
            text: "Are you sure you want to delete this " +
                  (deleteConfirmDialog.isDirectory ? "folder" : "file") + "?"
        }

        standardButtons: Dialog.Yes | Dialog.No

        onAccepted: {
            if (isDirectory) {
                ConnectionManager.deleteDirectory(itemPath)
            } else {
                ConnectionManager.deleteFile(itemPath)
            }
        }
    }

    function showDeleteConfirm(path, isDir) {
        deleteConfirmDialog.itemPath = path
        deleteConfirmDialog.isDirectory = isDir
        deleteConfirmDialog.open()
    }

    function showDownloadDialog(remotePath) {
        downloadDialog.remotePath = remotePath
        downloadDialog.open()
    }
}
