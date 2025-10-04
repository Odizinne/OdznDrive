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

    footer: Item {
        height: 50 + 24

        Rectangle {
            anchors.fill: parent
            anchors.margins: 12
            color: Constants.surfaceColor
            radius: 4
            layer.enabled: true
            layer.effect: RoundedElevationEffect {
                elevation: 6
                roundedScale: 4
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 10
                spacing: 7

                ToolButton {
                    Layout.preferredHeight: 50
                    Layout.preferredWidth: 50
                    Image {
                        anchors.centerIn: parent
                        sourceSize.height: 28
                        sourceSize.width: 28
                        source: "qrc:/icons/icon.png"
                    }
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

                    Item {
                        id: storageBar
                        Layout.preferredWidth: 150
                        Layout.preferredHeight: 8

                        property real value: 0

                        Rectangle {
                            anchors.fill: parent
                            radius: 4
                            color: Constants.borderColor
                            opacity: 1

                            Rectangle {
                                width: parent.width * storageBar.value
                                height: parent.height
                                radius: 4
                                color: storageBar.value < 0.5 ? "#66BB6A" : storageBar.value < 0.85 ? "#FF9800" : "#F44336"

                                Behavior on width {
                                    NumberAnimation {
                                        duration: 200
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 200
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignRight
                        spacing: 4

                        Label {
                            id: occupiedLabel
                            text: "--"
                            font.pixelSize: 11
                            font.bold: true
                            opacity: 0.7
                        }

                        Label {
                            text: "/"
                            font.pixelSize: 11
                            opacity: 0.7
                        }

                        Label {
                            id: totalLabel
                            text: "--"
                            font.pixelSize: 11
                            opacity: 0.7
                        }
                    }
                }
            }
        }
    }

    FileListView {
        anchors.fill: parent
        onShowSettings: settingsDialog.open()
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
