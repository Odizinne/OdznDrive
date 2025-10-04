import QtQuick
import QtQuick.Controls.Material
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
    Material.theme: Constants.darkMode ? Material.Dark : Material.Light
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
            storageBar.value = used / total
            occupiedLabel.text = root.formatStorage(used)
            totalLabel.text = root.formatStorage(total)
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

    footer: Rectangle {
        height: 44
        color: Constants.surfaceColor

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 5
            anchors.rightMargin: 10
            spacing: 4

            ToolButton {
                icon.source: "qrc:/icons/cog.svg"
                icon.width: 16
                icon.height: 16
                onClicked: settingsDialog.open()
                ToolTip.visible: hovered
                ToolTip.text: "Settings"
                Material.roundedScale: Material.ExtraSmallScale
            }

            TextField {
                id: filterField
                Layout.preferredWidth: 300
                Layout.preferredHeight: 35
                placeholderText: "Filter..."
                onTextChanged: FilterProxyModel.filterText = text
            }

            Item {
                Layout.fillWidth: true
            }

            ColumnLayout {
                spacing: 4

                ProgressBar {
                    id: storageBar
                    Layout.preferredWidth: 150
                    value: 0
                    Material.accent: value < 0.5 ? "#66BB6A" : value < 0.85 ? "#FF9800" : "#F44336"
                }

                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: 4

                    Label {
                        id: occupiedLabel
                        text: "--"
                        font.pixelSize: 10
                        font.bold: true
                        opacity: 0.7

                    }

                    Label {
                        text: "/"
                        font.pixelSize: 10
                        opacity: 0.7
                    }

                    Label {
                        id: totalLabel
                        text: "--"
                        font.pixelSize: 10
                        opacity: 0.7
                    }
                }
            }
        }
    }

    FileListView {
        anchors.fill: parent
    }

    CustomDialog {
        id: uploadProgressDialog
        title: "Uploading Files"
        closePolicy: Popup.NoAutoClose
        anchors.centerIn: parent
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

    CustomDialog {
        id: downloadProgressDialog
        title: ConnectionManager.isZipping ? "Compressing Folder" : "Downloading File"
        closePolicy: Popup.NoAutoClose
        anchors.centerIn: parent
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

    CustomDialog {
        id: errorDialog
        title: "Error"
        width: 300
        property alias text: errorLabel.text
        anchors.centerIn: parent
        Label {
            id: errorLabel
        }
        standardButtons: Dialog.Ok
    }

    SettingsDialog {
        id: settingsDialog
        anchors.centerIn: parent
    }
}
