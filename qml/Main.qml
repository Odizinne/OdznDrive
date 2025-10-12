pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Material
import Odizinne.OdznDrive

ApplicationWindow {
    id: root
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

    signal requestLoginReset()
    signal requestLoginAnimationPlay()
    signal requestLoginAnimationReset()
    signal requestSetLoginToServer()

    Component.onCompleted: {
        WindowsPlatform.setTitlebarColor(UserSettings.darkMode)
        if (UserSettings.autoconnect && UserSettings.serverUrl !== "" && UserSettings.serverUsername !== "" && UserSettings.serverPassword !== "") {
            ConnectionManager.connectToServer( UserSettings.serverUrl, UserSettings.serverUsername, UserSettings.serverPassword)
            root.requestSetLoginToServer()
        }
    }

    Shortcut {
        sequences: [StandardKey.Find]
        onActivated: Utils.focusSearch()
    }

    function refreshTreeView() {
        var expandedPaths = TreeModel.getExpandedPaths()
        var maxDepth = Math.max(TreeModel.getMaxDepth() + 1, 2)

        ConnectionManager.getFolderTree("", maxDepth)
        root.pendingExpandedPaths = expandedPaths
    }

    property var pendingExpandedPaths: []

    Connections {
        target: ConnectionManager

        function onAuthenticatedChanged() {
            if (ConnectionManager.authenticated) {
                ConnectionManager.listDirectory("", UserSettings.foldersFirst)
                ConnectionManager.getStorageInfo()
                ConnectionManager.getServerInfo()
                ConnectionManager.getFolderTree("", 2)
                Utils.clearNavigationHistory()
                Utils.pushToHistory("")
            } else {
                mainStack.pop()
                root.requestLoginReset()
                root.requestLoginAnimationReset()
                root.requestLoginAnimationPlay()
                Utils.clearNavigationHistory()
            }
        }

        function onMultipleMoved(fromPaths, toPath) {
            ConnectionManager.listDirectory(FileModel.currentPath, UserSettings.foldersFirst)
            storageUpdateTimer.restart()
            root.refreshTreeView()
        }

        function onFolderTreeReceived(tree) {
            TreeModel.loadTree(tree)

            if (root.pendingExpandedPaths.length > 0) {
                TreeModel.restoreExpandedPaths(root.pendingExpandedPaths)
                root.pendingExpandedPaths = []
            }
        }

        function onShareLinkGenerated(path, link) {
            shareableLinkDialog.shareableLink = link
            shareableLinkDialog.open()
        }

        function onDownloadZipping(name) {
            downloadProgressDialog.open()
        }

        function onItemRenamed(fromPath, newName) {
            ConnectionManager.listDirectory(FileModel.currentPath, UserSettings.foldersFirst)
            root.refreshTreeView()
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
            }
        }

        function onUploadProgress(progress) {
            uploadProgressDialog.progress = progress
            uploadProgressDialog.open()
        }

        //function onUploadComplete(path) {
        //    if (ConnectionManager.uploadQueueSize === 0) {
        //        uploadProgressDialog.close()
        //    }
        //    ConnectionManager.listDirectory(FileModel.currentPath, UserSettings.foldersFirst)
        //    storageUpdateTimer.restart()
        //}

        function onUploadComplete(path) {
            // This is only emitted when ALL uploads are done
            uploadProgressDialog.close()
            ConnectionManager.listDirectory(FileModel.currentPath, UserSettings.foldersFirst)
            storageUpdateTimer.restart()
            root.refreshTreeView()
        }

        function onUploadQueueSizeChanged() {
            // Close dialog if queue is empty and no current upload
            if (ConnectionManager.uploadQueueSize === 0 && !ConnectionManager.currentUploadFileName) {
                uploadProgressDialog.close()
            }
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
            root.refreshTreeView()
        }

        function onFileDeleted(path) {
            ConnectionManager.listDirectory(FileModel.currentPath, UserSettings.foldersFirst)
            storageUpdateTimer.restart()
        }

        function onDirectoryDeleted(path) {
            ConnectionManager.listDirectory(FileModel.currentPath, UserSettings.foldersFirst)
            storageUpdateTimer.restart()
            root.refreshTreeView()
        }

        function onMultipleDeleted() {
            ConnectionManager.listDirectory(FileModel.currentPath, UserSettings.foldersFirst)
            storageUpdateTimer.restart()
            root.refreshTreeView()
        }

        function onItemMoved(fromPath, toPath) {
            ConnectionManager.listDirectory(FileModel.currentPath, UserSettings.foldersFirst)
            storageUpdateTimer.restart()
            root.refreshTreeView()
        }

        function onStorageInfo(total, used, available) {
            Utils.storagePercentage = used / total
            Utils.storageOccupied = Utils.formatStorage(used)
            Utils.storageTotal = Utils.formatStorage(total)
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

    CustomStackView {
        id: mainStack
        anchors.fill: parent
        initialItem: loginPage
    }

    Component {
        id: loginPage
        LoginPage {
            id: lp
            onLoginComplete: {
                mainStack.push(fileSystemView)
            }

            Connections {
                target: root

                function onRequestLoginReset() {
                    lp.reset()
                }

                function onRequestLoginAnimationReset() {
                    lp.resetAnimation()
                }

                function onRequestLoginAnimationPlay() {
                    lp.playAnimation()
                }

                function onRequestSetLoginToServer() {
                    lp.setLoginToServer()
                }
            }
        }
    }

    Component {
        id: fileSystemView
        FileSystemView {}
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

    ShareableLinkDialog {
        id: shareableLinkDialog
        anchors.centerIn: parent
    }
}
