pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Material
import QtQuick.Layouts
import Odizinne.OdznDrive

Item {
    id: root

    Connections {
        target: FileModel
        function onCurrentPathChanged() {
            Utils.uncheckAll()
        }
    }

    Connections {
        target: Utils
        function onRequestSettingsDialog() {
            settingsDialog.open()
        }
    }

    DragIndicator {
        id: dragIndicator
    }

    RenameDialog {
        id: renameDialog
        anchors.centerIn: parent
    }

    NewFolderDialog {
        id: newFolderDialog
        anchors.centerIn: parent
    }

    DeleteConfirmDialog {
        id: deleteConfirmDialog
        anchors.centerIn: parent
    }

    MultiDeleteConfirmDialog {
        id: multiDeleteConfirmDialog
        anchors.centerIn: parent
    }

    DropArea {
        id: dropArea
        anchors.fill: parent

        onEntered: (drag) => {
            if (drag.hasUrls && ConnectionManager.authenticated) {
                drag.accept(Qt.CopyAction)
                dropOverlay.visible = true
            }
        }

        onExited: {
            dropOverlay.visible = false
        }

        onDropped: (drop) => {
            dropOverlay.visible = false

            if (drop.hasUrls && ConnectionManager.authenticated) {
                let files = []
                for (let i = 0; i < drop.urls.length; i++) {
                    let fileUrl = drop.urls[i].toString()

                    let localPath = fileUrl
                    if (localPath.startsWith("file://")) {
                        localPath = localPath.substring(7)
                    }

                    if (localPath.match(/^\/[A-Za-z]:\//)) {
                        localPath = localPath.substring(1)
                    }

                    files.push(localPath)
                }

                if (files.length > 0) {
                    ConnectionManager.uploadFiles(files, FileModel.currentPath)
                }

                drop.accept(Qt.CopyAction)
            }
        }

        Rectangle {
            id: dropOverlay
            anchors.fill: parent
            color: Material.primary
            opacity: 0.2
            visible: false

            Label {
                anchors.centerIn: parent
                text: "Drop files here to upload"
                font.pixelSize: 24
                font.bold: true
                color: Material.primary
            }
        }
    }

    EmptySpaceMenu {
        id: emptySpaceMenu
        onNewFolderClicked: newFolderDialog.open()
        onUploadFilesClicked: Utils.openUploadDialog()
        onRefreshClicked: ConnectionManager.listDirectory(FileModel.currentPath, UserSettings.foldersFirst)
    }

    SettingsDialog {
        id: settingsDialog
        anchors.centerIn: parent
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        BreadcrumBar {
            id: breadcrumbBar
            Layout.margins: 12
            Layout.preferredHeight: 45
            Layout.fillWidth: true
            onShowSettings: settingsDialog.open()
            onRequestNewFolderDialog: newFolderDialog.open()
            onRequestMultiDeleteConfirmDialog: {
                multiDeleteConfirmDialog.itemCount = Utils.checkedCount
                multiDeleteConfirmDialog.open()
            }
        }

        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            sourceComponent: UserSettings.listView ? listViewComponent : tileViewComponent
        }
    }

    Component {
        id: listViewComponent

        FileListView {
            ContextMenu.menu: emptySpaceMenu
            onRequestRename: function(path, name) {
                renameDialog.itemPath = path
                renameDialog.itemName = name
                renameDialog.open()
            }

            onRequestDelete: function (path, isDir) {
                deleteConfirmDialog.itemPath = path
                deleteConfirmDialog.isDirectory = isDir
                deleteConfirmDialog.open()
            }

            onSetDragIndicatorX: function(x) {
                dragIndicator.x = x
            }

            onSetDragIndicatorY: function(y) {
                dragIndicator.y = y
            }

            onSetDragIndicatorVisible: function(visible) {
                dragIndicator.visible = visible
            }

            onSetDragIndicatorText: function (text) {
                dragIndicator.text = text
            }
        }
    }

    Component {
        id: tileViewComponent

        FileTileView {
            ContextMenu.menu: emptySpaceMenu
            onRequestRename: function(path, name) {
                renameDialog.itemPath = path
                renameDialog.itemName = name
                renameDialog.open()
            }

            onRequestDelete: function (path, isDir) {
                deleteConfirmDialog.itemPath = path
                deleteConfirmDialog.isDirectory = isDir
                deleteConfirmDialog.open()
            }

            onSetDragIndicatorX: function(x) {
                dragIndicator.x = x
            }

            onSetDragIndicatorY: function(y) {
                dragIndicator.y = y
            }

            onSetDragIndicatorVisible: function(visible) {
                dragIndicator.visible = visible
            }

            onSetDragIndicatorText: function (text) {
                dragIndicator.text = text
            }
        }
    }
}
