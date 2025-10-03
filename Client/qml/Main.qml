import QtQuick
import QtQuick.Controls.Material
import QtQuick.Layouts
import Odizinne.OdznDriveClient

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
            ConnectionManager.listDirectory(FileModel.currentPath)
            storageUpdateTimer.restart()
        }

        function onDownloadProgress(progress) {
            // Could add download progress UI here
        }

        function onDownloadComplete(path) {
            // Could add download complete notification here
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

    Dialog {
        id: uploadProgressDialog
        title: "Uploading Files"
        modal: true
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

    Dialog {
        id: errorDialog
        title: "Error"
        width: 300
        property alias text: errorLabel.text
        modal: true
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
