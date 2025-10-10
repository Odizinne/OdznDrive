pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Material
import QtQuick.Layouts
import Odizinne.OdznDrive

Page {
    id: root
    Material.background: "transparent"

    Component.onCompleted: {
        if (UserSettings.firstRun) {
            advancedSettingsDialog.open()
            UserSettings.firstRun = false
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        acceptedButtons: Qt.BackButton | Qt.ForwardButton
        propagateComposedEvents: true

        onPressed: (mouse) => {
            if (mouse.button === Qt.BackButton) {
                Utils.goBack()
                mouse.accepted = true
            } else if (mouse.button === Qt.ForwardButton) {
                Utils.goForward()
                mouse.accepted = true
            } else {
                mouse.accepted = false
            }
        }

        onClicked: (mouse) => { mouse.accepted = false }
        onDoubleClicked: (mouse) => { mouse.accepted = false }
        onReleased: (mouse) => { mouse.accepted = false }
    }

    Binding {
        target: Utils
        property: "anyDialogOpen"
        value: renameDialog.visible ||
               newFolderDialog.visible ||
               deleteConfirmDialog.visible ||
               multiDeleteConfirmDialog.visible ||
               userAddDialog.visible ||
               userManagmentDialog.visible ||
               confirmDeleteUserDialog.visible
    }

    Connections {
        target: FileModel

        function onCurrentPathChanged() {
            Utils.uncheckAll()
            if (!Utils.isNavigating) {
                Utils.pushToHistory(FileModel.currentPath)
            } else {
                Utils.isNavigating = false
            }
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

    Label {
        anchors.centerIn: parent
        text: ConnectionManager.authenticated ?
                  (FileModel.count === 0 ? "Empty folder\n\nDrag files here to upload" :
                                           FilterProxyModel.rowCount() === 0 ? "No items match filter" : "") :
                  "Not connected"
        visible: ConnectionManager.authenticated ?
                     (FileModel.count === 0 || FilterProxyModel.rowCount() === 0) :
                     true
        opacity: 0.5
        font.pixelSize: 16
        horizontalAlignment: Text.AlignHCenter
    }

    EmptySpaceMenu {
        id: emptySpaceMenu
        onNewFolderClicked: newFolderDialog.open()
        onUploadFilesClicked: Utils.openUploadDialog()
        onRefreshClicked: ConnectionManager.listDirectory(FileModel.currentPath, UserSettings.foldersFirst)
    }

    CustomSplitView {
        id: split
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.bottomMargin: 12
        handleSpacing: 12

        FolderTreeView {
            SplitView.minimumWidth: 250
            SplitView.preferredWidth: 250
            SplitView.maximumWidth: 400
        }

        Loader {
            SplitView.fillWidth: true
            SplitView.fillHeight: true
            sourceComponent: UserSettings.listView ? listViewComponent : tileViewComponent
        }
    }

    header: BreadcrumBar {
        id: breadcrumbBar
        Layout.margins: 12
        Layout.preferredHeight: 45
        Layout.fillWidth: true
        onRequestNewFolderDialog: newFolderDialog.open()
        onRequestMultiDeleteConfirmDialog: {
            multiDeleteConfirmDialog.itemCount = Utils.checkedCount
            multiDeleteConfirmDialog.open()
        }
    }

    AdvancedSettingsDialog {
        id: advancedSettingsDialog
        anchors.centerIn: parent
    }

    UserAddDialog {
        id: userAddDialog
        anchors.centerIn: parent
    }

    UserManagmentDialog {
        id: userManagmentDialog
        anchors.centerIn: parent
        onOpenUserAddDialog: userAddDialog.open()
        onOpenUserConfirmDeleteDialog: function (name) {
            confirmDeleteUserDialog.username = name
            confirmDeleteUserDialog.open()
        }
        onOpenUserEditDialog: function (name, pass, storage, isAdmin) {
            userAddDialog.openInEditMode(name, pass, storage, isAdmin)
        }
    }

    ConfirmDeleteUserDialog {
        id: confirmDeleteUserDialog
        width: 300
        title: "Delete " + confirmDeleteUserDialog.username + "?"
        anchors.centerIn: parent
    }

    Component {
        id: listViewComponent

        FileListView {
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
            Component.onCompleted: setScrollViewMenu(emptySpaceMenu)
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
