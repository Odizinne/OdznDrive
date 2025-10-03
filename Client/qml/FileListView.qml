pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Material
import QtQuick.Controls.impl
import QtQuick.Layouts
import Odizinne.OdznDriveClient

Rectangle {
    id: root
    color: Constants.backgroundColor

    // Drag indicator that follows the mouse
    Rectangle {
        id: dragIndicator
        visible: false
        width: dragLabel.implicitWidth + 20
        height: 40
        color: Material.primary
        radius: 4
        opacity: 0.7
        z: 1000
        parent: Overlay.overlay

        Label {
            id: dragLabel
            anchors.centerIn: parent
            color: Material.foreground
            font.bold: true
        }
    }

    property string draggedItemPath: ""
    property string draggedItemName: ""
    property var currentDropTarget: null

    // Drop area for file uploads
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

                    // Remove file:// prefix to get local path
                    let localPath = fileUrl
                    if (localPath.startsWith("file://")) {
                        localPath = localPath.substring(7)
                    }

                    // On Windows, remove leading slash before drive letter
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

    // Context menu for empty space
    Menu {
        id: emptySpaceMenu
        width: 200

        MenuItem {
            text: "New Folder"
            icon.source: "qrc:/icons/plus.svg"
            icon.width: 16
            icon.height: 16
            enabled: ConnectionManager.authenticated
            onClicked: newFolderDialog.open()
        }
    }

    // New folder dialog
    Dialog {
        id: newFolderDialog
        title: "Create New Folder"
        modal: true
        parent: Overlay.overlay
        anchors.centerIn: parent

        ColumnLayout {
            spacing: 10

            Label {
                text: "Folder name:"
            }

            TextField {
                id: folderNameField
                Layout.preferredWidth: 300
                placeholderText: "Enter folder name"
                onAccepted: newFolderDialog.accepted()
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

    ScrollView {
        id: scrollView
        anchors.fill: parent
        clip: true

        ListView {
            id: listView
            width: scrollView.width
            model: FileModel
            interactive: false

            // Right-click handler for empty space
            TapHandler {
                acceptedButtons: Qt.RightButton
                onTapped: {
                    if (ConnectionManager.authenticated) {
                        emptySpaceMenu.popup()
                    }
                }
            }

            headerPositioning: ListView.OverlayHeader

            header: Item {
                width: listView.width
                height: 45 + 40 + (FileModel.canGoUp ? 50 : 0)
                z: 2

                // Breadcrumb navigation bar
                Rectangle {
                    id: breadcrumbBar
                    width: parent.width
                    height: 45
                    color: Qt.lighter(Constants.listHeaderColor, 1.15)

                    ScrollView {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        contentWidth: breadcrumbRow.implicitWidth
                        clip: true

                        Row {
                            id: breadcrumbRow
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            Button {
                                id: rootButton
                                text: "odzndrive"
                                flat: true
                                font.pixelSize: 13
                                implicitWidth: contentItem.implicitWidth + 20
                                onClicked: ConnectionManager.listDirectory("")
                                font.bold: root.getPathSegments().length === 0
                                opacity: root.getPathSegments().length === 0 || rootHover.hovered ? 1 : 0.7
                                Material.roundedScale: Material.ExtraSmallScale

                                HoverHandler {
                                    id: rootHover
                                }
                            }

                            Repeater {
                                id: segmentsRepeater
                                model: root.getPathSegments()

                                Row {
                                    id: pathBtn
                                    required property string modelData
                                    required property int index
                                    spacing: 6

                                    IconImage {
                                        source: "qrc:/icons/right.svg"
                                        sourceSize.width: 10
                                        sourceSize.height: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: Material.foreground
                                        opacity: 0.7
                                    }

                                    Button {
                                        text: pathBtn.modelData
                                        flat: true
                                        font.pixelSize: 13
                                        implicitWidth: contentItem.implicitWidth + 20
                                        Material.roundedScale: Material.ExtraSmallScale
                                        font.bold: pathBtn.index === segmentsRepeater.count - 1
                                        opacity: pathBtn.index === segmentsRepeater.count - 1 || pathBtnHover.hovered ? 1 : 0.7
                                        onClicked: {
                                            ConnectionManager.listDirectory(root.getPathUpToIndex(pathBtn.index))
                                        }

                                        HoverHandler {
                                            id: pathBtnHover
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Column headers
                Rectangle {
                    id: columnHeader
                    width: parent.width
                    height: 40
                    anchors.top: breadcrumbBar.bottom
                    color: Constants.listHeaderColor

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        Label {
                            text: "Name"
                            font.bold: true
                            Layout.fillWidth: true
                        }

                        Label {
                            text: "Size"
                            font.bold: true
                            Layout.preferredWidth: 100
                        }

                        Label {
                            text: "Modified"
                            font.bold: true
                            Layout.preferredWidth: 180
                        }

                        Item {
                            Layout.preferredWidth: 80
                        }
                    }
                }

                // Parent directory navigation item
                Rectangle {
                    id: parentDirItem
                    visible: FileModel.canGoUp
                    width: parent.width
                    height: 50
                    anchors.top: columnHeader.bottom
                    color: {
                        if (root.currentDropTarget === parentDirItem) {
                            return Constants.listHeaderColor
                        }
                        return parentHoverHandler.hovered ? Constants.alternateRowColor : "transparent"
                    }

                    property bool itemIsDir: true
                    property string itemPath: FileModel.getParentPath()
                    property string itemName: ".."

                    Rectangle {
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        height: 1
                        width: parent.width
                        color: Constants.alternateRowColor
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        Label {
                            text: "📁 .."
                            Layout.fillWidth: true
                            font.bold: true
                            opacity: 0.7
                        }

                        Label {
                            text: "-"
                            Layout.preferredWidth: 100
                            opacity: 0.7
                        }

                        Label {
                            text: "Parent Directory"
                            Layout.preferredWidth: 180
                            opacity: 0.7
                        }

                        Item {
                            Layout.preferredWidth: 80
                        }
                    }

                    HoverHandler {
                        id: parentHoverHandler
                    }

                    TapHandler {
                        acceptedButtons: Qt.LeftButton
                        onTapped: {
                            ConnectionManager.listDirectory(FileModel.getParentPath())
                        }
                    }
                }
            }

            delegate: Item {
                id: delegateRoot
                width: listView.width
                height: 50
                required property var model
                required property int index

                property string itemPath: model.path
                property string itemName: model.name
                property bool itemIsDir: model.isDir

                ContextMenu.menu: delContextMenu
                Menu {
                    id: delContextMenu
                    width: 200
                    MenuItem {
                        text: delegateRoot.model.name
                        enabled: false
                    }

                    MenuItem {
                        text: "Download"
                        icon.source: "qrc:/icons/download.svg"
                        icon.width: 16
                        icon.height: 16
                        onClicked: {
                            Intercom.requestShowDownloadDialog(delegateRoot.model.path)
                        }
                    }
                    MenuItem {
                        text: "Rename"
                        icon.source: "qrc:/icons/rename.svg"
                        icon.width: 16
                        icon.height: 16
                    }
                    MenuItem {
                        text: "Delete"
                        icon.source: "qrc:/icons/delete.svg"
                        icon.width: 16
                        icon.height: 16
                        onClicked: {
                            Intercom.requestShowDeleteConfirm(delegateRoot.model.path, delegateRoot.model.isDir)
                        }
                    }
                }

                Rectangle {
                    id: delegateBackground
                    anchors.fill: parent
                    color: {
                        if (root.currentDropTarget === delegateRoot && delegateRoot.model.isDir && root.draggedItemPath !== delegateRoot.model.path) {
                            return Constants.listHeaderColor
                        }
                        return hoverHandler.hovered ? Constants.alternateRowColor : "transparent"
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        height: 1
                        width: parent.width
                        color: Constants.alternateRowColor
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        Label {
                            text: (delegateRoot.model.isDir ? "📁 " : "📄 ") + delegateRoot.model.name
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        Label {
                            text: delegateRoot.model.isDir ? "-" : root.formatSize(delegateRoot.model.size)
                            Layout.preferredWidth: 100
                            opacity: 0.7
                        }

                        Label {
                            text: root.formatDate(delegateRoot.model.modified)
                            Layout.preferredWidth: 180
                            opacity: 0.7
                        }

                        RowLayout {
                            Layout.preferredWidth: 80
                            spacing: 2

                            ToolButton {
                                icon.source: "qrc:/icons/menu.svg"
                                icon.width: 16
                                icon.height: 16
                                onClicked: delContextMenu.popup()
                                Layout.alignment: Qt.AlignRight
                                opacity: (hoverHandler.hovered && root.draggedItemPath === "") ? 1 : 0
                            }
                        }
                    }

                    HoverHandler {
                        id: hoverHandler
                    }

                    DragHandler {
                        id: dragHandler
                        target: null
                        dragThreshold: 15

                        onActiveChanged: {
                            if (active) {
                                root.draggedItemPath = delegateRoot.model.path
                                root.draggedItemName = delegateRoot.model.name
                                dragLabel.text = "Move " + delegateRoot.model.name
                                dragIndicator.visible = true
                            } else {
                                dragIndicator.visible = false

                                if (root.currentDropTarget) {
                                    let targetPath = root.currentDropTarget.itemPath

                                    // Check if dropping on parent directory item or regular directory
                                    if (root.currentDropTarget.itemIsDir &&
                                        targetPath !== root.draggedItemPath) {
                                        ConnectionManager.moveItem(root.draggedItemPath, targetPath)
                                    }
                                }

                                root.draggedItemPath = ""
                                root.draggedItemName = ""
                                root.currentDropTarget = null
                            }
                        }

                        onCentroidChanged: {
                            if (active) {
                                let globalPos = delegateBackground.mapToItem(null, centroid.position.x, centroid.position.y)
                                dragIndicator.x = globalPos.x + 10
                                dragIndicator.y = globalPos.y + 10

                                let listPos = delegateBackground.mapToItem(listView, centroid.position.x, centroid.position.y)

                                root.currentDropTarget = null

                                // Check parent directory item if visible
                                if (FileModel.canGoUp) {
                                    let headerItem = listView.headerItem
                                    if (headerItem) {
                                        let parentDirItem = headerItem.children[2] // The parent dir rectangle (now third child)
                                        if (parentDirItem) {
                                            let parentPos = parentDirItem.mapFromItem(listView, listPos.x, listPos.y)
                                            if (parentPos.x >= 0 && parentPos.x <= parentDirItem.width &&
                                                parentPos.y >= 0 && parentPos.y <= parentDirItem.height) {
                                                root.currentDropTarget = parentDirItem
                                                return
                                            }
                                        }
                                    }
                                }

                                // Check regular file items
                                for (let i = 0; i < listView.count; i++) {
                                    let item = listView.itemAtIndex(i)
                                    if (item) {
                                        let itemPos = item.mapFromItem(listView, listPos.x, listPos.y)
                                        if (itemPos.x >= 0 && itemPos.x <= item.width &&
                                            itemPos.y >= 0 && itemPos.y <= item.height) {
                                            root.currentDropTarget = item
                                            break
                                        }
                                    }
                                }
                            }
                        }
                    }

                    TapHandler {
                        acceptedButtons: Qt.LeftButton
                        onDoubleTapped: {
                            if (delegateRoot.model.isDir) {
                                ConnectionManager.listDirectory(delegateRoot.model.path)
                            }
                        }
                    }
                }
            }

            Label {
                anchors.centerIn: parent
                text: ConnectionManager.authenticated ?
                          (FileModel.count === 0 ? "Empty folder\n\nDrag files here to upload" : "") :
                          "Not connected"
                visible: FileModel.count === 0
                opacity: 0.5
                font.pixelSize: 16
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    function getPathSegments() {
        if (!FileModel.currentPath || FileModel.currentPath === "" || FileModel.currentPath === "/") {
            return []
        }

        let path = FileModel.currentPath
        if (path.startsWith("/")) {
            path = path.substring(1)
        }
        if (path.endsWith("/")) {
            path = path.substring(0, path.length - 1)
        }

        return path.split("/")
    }

    function getPathUpToIndex(index) {
        let segments = getPathSegments()
        let pathParts = segments.slice(0, index + 1)
        return pathParts.join("/")
    }

    function formatSize(bytes) {
        if (bytes < 1024) return bytes + " B"
        if (bytes < 1024 * 1024) return Math.round(bytes / 1024) + " KB"
        if (bytes < 1024 * 1024 * 1024) return Math.round(bytes / 1024 / 1024) + " MB"
        return Math.round(bytes / 1024 / 1024 / 1024) + " GB"
    }

    function formatDate(dateString) {
        let date = new Date(dateString)
        return date.toLocaleString(Qt.locale(), "yyyy-MM-dd HH:mm")
    }
}
