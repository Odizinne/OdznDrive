import QtQuick
import QtQuick.Controls.Material
import Odizinne.OdznDrive

ApplicationWindow {
    visible: true
    width: 1280
    height: 720
    minimumWidth: 1280
    minimumHeight: 720
    title: "OdznDrive Client"
    color: Constants.backgroundColor
    Material.accent: "#FF9F5A"
    Material.primary: "#E67E22"
    Material.theme: UserSettings.darkMode ? Material.Dark : Material.Light

    Component.onCompleted: {
        WindowsPlatform.setTitlebarColor(UserSettings.darkMode)
        if (UserSettings.autoconnect) {
            ConnectionManager.connectToServer(UserSettings.serverUrl, UserSettings.serverPassword)
        } else {
            Utils.requestSettingsDialog()
        }
    }

    Connections {
        target: ConnectionManager

        function onAuthenticatedChanged() {
            if (ConnectionManager.authenticated) {
                ConnectionManager.listDirectory("", UserSettings.foldersFirst)
                ConnectionManager.getStorageInfo()
                ConnectionManager.getServerInfo()
            }
        }

        function onItemRenamed(fromPath, newName) {
            ConnectionManager.listDirectory(FileModel.currentPath, UserSettings.foldersFirst)
        }

        function onDirectoryListed(path, files) {
            FileModel.loadDirectory(path, files)
        }

        function onThumbnailReady(path) {
            FileModel.refreshThumbnail(path)
        }

        function onErrorOccurred(error) {
            uploadProgressDialog.close()
            downloadProgressDialog.close()

            if (error !== "Upload cancelled by user" && error !== "Download cancelled by user") {
                errorDialog.text = error
                errorDialog.open()

                if (!ConnectionManager.connected) {
                    Utils.requestSettingsDialog()
                }
            }
        }

        function onUploadProgress(progress) {
            uploadProgressDialog.progress = progress
            uploadProgressDialog.open()
        }

        function onUploadComplete(path) {
            if (ConnectionManager.uploadQueueSize === 0) {
                uploadProgressDialog.close()
            }
            ConnectionManager.listDirectory(FileModel.currentPath, UserSettings.foldersFirst)
            storageUpdateTimer.restart()
        }

        function onDownloadProgress(progress) {
            downloadProgressDialog.progress = progress
            downloadProgressDialog.open()
        }

        function onDownloadComplete(path) {
            downloadProgressDialog.close()
        }

        function onDirectoryCreated(path) {
            ConnectionManager.listDirectory(FileModel.currentPath, UserSettings.foldersFirst)
        }

        function onFileDeleted(path) {
            ConnectionManager.listDirectory(FileModel.currentPath, UserSettings.foldersFirst)
            storageUpdateTimer.restart()
        }

        function onDirectoryDeleted(path) {
            ConnectionManager.listDirectory(FileModel.currentPath, UserSettings.foldersFirst)
            storageUpdateTimer.restart()
        }

        function onMultipleDeleted() {
            ConnectionManager.listDirectory(FileModel.currentPath, UserSettings.foldersFirst)
            storageUpdateTimer.restart()
        }

        function onItemMoved(fromPath, toPath) {
            ConnectionManager.listDirectory(FileModel.currentPath, UserSettings.foldersFirst)
            storageUpdateTimer.restart()
        }

        function onStorageInfo(total, used, available) {
            footerBar.storagePercentage = used / total
            footerBar.storageOccupied = Utils.formatStorage(used)
            footerBar.storageTotal = Utils.formatStorage(total)
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

    footer: FooterBar {
        id: footerBar
    }

    FileSystemView {
        anchors.fill: parent
    }

    UploadProgressDialog {
        id: uploadProgressDialog
        anchors.centerIn: parent
    }

    DownloadProgressDialog {
        id: downloadProgressDialog
        anchors.centerIn: parent
    }

    ErrorDialog {
        id: errorDialog
        anchors.centerIn: parent
    }
}
