import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import Odizinne.OdznDriveClient

ApplicationWindow {
    id: root
    visible: true
    width: 1000
    height: 700
    title: "OdznDrive Client"
    
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
            errorDialog.text = error
            errorDialog.open()
        }
        
        function onUploadComplete(path) {
            statusLabel.text = "Upload complete: " + path
            ConnectionManager.listDirectory(FileModel.currentPath)
        }
        
        function onDownloadComplete(path) {
            statusLabel.text = "Download complete: " + path
        }
        
        function onDirectoryCreated(path) {
            ConnectionManager.listDirectory(FileModel.currentPath)
        }
        
        function onFileDeleted(path) {
            ConnectionManager.listDirectory(FileModel.currentPath)
        }
        
        function onDirectoryDeleted(path) {
            ConnectionManager.listDirectory(FileModel.currentPath)
        }
        
        function onStorageInfo(total, used, available) {
            storageBar.value = used / total
            let usedMB = Math.round(used / 1024 / 1024)
            let totalMB = Math.round(total / 1024 / 1024)
            storageLabel.text = `Storage: ${usedMB} MB / ${totalMB} MB`
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
            Layout.preferredHeight: 40
            color: "#f5f5f5"
            border.color: "#e0e0e0"
            border.width: 1
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 10
                
                Button {
                    text: "↑ Up"
                    enabled: FileModel.canGoUp() && ConnectionManager.authenticated
                    onClicked: {
                        let parentPath = FileModel.getParentPath()
                        ConnectionManager.listDirectory(parentPath)
                    }
                }
                
                Button {
                    text: "⟳ Refresh"
                    enabled: ConnectionManager.authenticated
                    onClicked: {
                        ConnectionManager.listDirectory(FileModel.currentPath)
                    }
                }
                
                Button {
                    text: "+ New Folder"
                    enabled: ConnectionManager.authenticated
                    onClicked: newFolderDialog.open()
                }
                
                Button {
                    text: "↑ Upload"
                    enabled: ConnectionManager.authenticated
                    onClicked: uploadDialog.open()
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
            color: "#f5f5f5"
            border.color: "#e0e0e0"
            border.width: 1
            
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
        fileMode: FileDialog.OpenFile
        onAccepted: {
            let fileUrl = selectedFile.toString()

            // Remove file:// prefix to get local path
            let localPath = fileUrl
            if (localPath.startsWith("file://")) {
                localPath = localPath.substring(7)
            }

            let fileName = localPath.substring(localPath.lastIndexOf('/') + 1)

            let remotePath = FileModel.currentPath
            if (remotePath && !remotePath.endsWith('/')) {
                remotePath += '/'
            }
            remotePath += fileName

            ConnectionManager.uploadFile(localPath, remotePath)
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

            ConnectionManager.downloadFile(remotePath, localPath)
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
