import QtQuick
import QtQuick.Controls.Material
import QtQuick.Controls.Material.impl
import QtQuick.Layouts
import Odizinne.OdznDrive

ApplicationWindow {
    id: root
    visible: true
    width: 1280
    height: 720
    minimumWidth: 1280
    minimumHeight: 720
    title: "OdznDrive Client"
    Material.theme: UserSettings.darkMode ? Material.Dark : Material.Light
    color: Constants.backgroundColor
    Material.accent: "#FF9F5A"
    Material.primary: "#E67E22"

    Component.onCompleted: {
        if (UserSettings.autoconnect) {
            ConnectionManager.connectToServer(UserSettings.serverUrl, UserSettings.serverPassword)
        } else {
            settingsDialog.open()
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
                    settingsDialog.open()
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
            footerBar.storageOccupied = root.formatStorage(used)
            footerBar.storageTotal = root.formatStorage(total)
        }

        function onUploadQueueSizeChanged() {
            if (ConnectionManager.uploadQueueSize === 0 && !ConnectionManager.currentUploadFileName) {
                uploadProgressDialog.close()
            }
        }
    }

    function formatStorage(bytes) {
        let mb = bytes / (1024 * 1024)

        if (mb >= 1000) {
            let gb = mb / 1024
            return gb.toFixed(1) + " GB"
        }

        return Math.round(mb) + " MB"
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

    FileListView {
        anchors.fill: parent
        onShowSettings: settingsDialog.open()
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

    SettingsDialog {
        id: settingsDialog
        anchors.centerIn: parent
    }
}
