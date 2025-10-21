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
               confirmDeleteUserDialog.visible ||
               imagePreviewDialog.visible ||
               textPreviewDialog.visible
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

    Connections {
        target: Utils
        function onShowUserManagmentDialog() {
            userManagmentDialog.open()
        }

        function onShowAdvancedSettingsDialog() {
            advancedSettingsDialog.open()
        }

        function onRequestMultiDeleteConfirmDialog() {
            multiDeleteConfirmDialog.itemCount = Utils.checkedCount
            multiDeleteConfirmDialog.open()
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

    ImagePreviewDialog {
        id: imagePreviewDialog
        anchors.centerIn: parent
        width: parent.width - 80
        height: parent.height - 80
    }

    TextPreviewDialog {
        id: textPreviewDialog
        anchors.centerIn: parent
    }

    EmptySpaceMenu {
        id: emptySpaceMenu
        onNewFolderClicked: newFolderDialog.open()
        onUploadFilesClicked: Utils.openUploadDialog()
        onRefreshClicked: ConnectionManager.listDirectory(FileModel.currentPath, UserSettings.foldersFirst)
    }

    CustomSplitView {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.bottomMargin: 12
        handleSpacing: 12

        FolderTreeView {
            SplitView.minimumWidth: UserSettings.compactSidePane ? 45 : 250
            SplitView.preferredWidth: UserSettings.compactSidePane ? 45 : 250
            SplitView.maximumWidth: UserSettings.compactSidePane ? 45 : 400
        }

        Loader {
            id: loader
            SplitView.fillWidth: true
            SplitView.fillHeight: true
            sourceComponent: UserSettings.listView ? listViewComponent : tileViewComponent

            onSourceComponentChanged: {
                if (item) {
                    enterAnimation.running = true
                }
            }

            DropArea {
                id: dropArea
                anchors.fill: parent

                onEntered: (drag) => {
                    if (drag.hasUrls && ConnectionManager.authenticated) {
                        drag.accept(Qt.CopyAction)
                        Utils.dropAreaVisible = true
                    }
                }

                onExited: {
                    Utils.dropAreaVisible = false
                }

                onDropped: (drop) => {
                    Utils.dropAreaVisible = false

                    if (drop.hasUrls && ConnectionManager.authenticated) {
                        let files = []
                        let hasFolders = false

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

                            if (FileDialogHelper.isDirectory(localPath)) {
                                hasFolders = true
                            }
                        }

                        if (files.length > 0) {
                            if (hasFolders || files.length > 1) {
                                // Mixed upload or multiple items
                                ConnectionManager.uploadMixed(files, FileModel.currentPath)
                            } else {
                                // Single file
                                ConnectionManager.uploadFiles(files, FileModel.currentPath)
                            }
                        }

                        drop.accept(Qt.CopyAction)
                    }
                }
            }

            ParallelAnimation {
                id: enterAnimation

                NumberAnimation {
                    target: loader.item
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: 200
                    easing.type: Easing.InQuint
                }

                NumberAnimation {
                    target: loader.item
                    property: "x"
                    from: loader.width * 0.3
                    to: 0
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    header: BreadcrumBar {
        Layout.margins: 12
        Layout.preferredHeight: 45
        Layout.fillWidth: true
        onRequestNewFolderDialog: newFolderDialog.open()
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

            onRequestPreview: function(path, name) {
                if (Utils.isImageFile(name)) {
                    imagePreviewDialog.filePath = path
                    imagePreviewDialog.fileName = name
                    imagePreviewDialog.open()
                } else if (Utils.isEditableTextFile(name)) {
                    textPreviewDialog.filePath = path
                    textPreviewDialog.fileName = name
                    textPreviewDialog.open()
                }
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

            onRequestPreview: function(path, name) {
                if (Utils.isImageFile(name)) {
                    imagePreviewDialog.filePath = path
                    imagePreviewDialog.fileName = name
                    imagePreviewDialog.open()
                } else if (Utils.isEditableTextFile(name)) {
                    textPreviewDialog.filePath = path
                    textPreviewDialog.fileName = name
                    textPreviewDialog.open()
                }
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
