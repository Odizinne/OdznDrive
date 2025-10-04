pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Material
import QtQuick.Controls.impl
import QtQuick.Layouts
import QtQuick.Dialogs
import Odizinne.OdznDrive

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

    // File upload dialog
    FileDialog {
        id: uploadDialog
        fileMode: FileDialog.OpenFiles
        onAccepted: {
            let files = []
            for (let i = 0; i < selectedFiles.length; i++) {
                let fileUrl = selectedFiles[i].toString()

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
        }
    }

    FileDialog {
        id: fileDownloadDialog
        fileMode: FileDialog.SaveFile
        property string remotePath: ""
        property string defaultName: ""

        currentFile: defaultName ? "file:///" + defaultName : ""

        onAccepted: {
            let localPath = selectedFile.toString()

            if (localPath.startsWith("file://")) {
                localPath = localPath.substring(7)
            }

            if (localPath.match(/^\/[A-Za-z]:\//)) {
                localPath = localPath.substring(1)
            }

            ConnectionManager.downloadFile(remotePath, localPath)
        }
    }

    // Folder download dialog
    FileDialog {
        id: folderDownloadDialog
        fileMode: FileDialog.SaveFile
        property string remotePath: ""
        property string defaultName: ""

        currentFile: defaultName ? "file:///" + defaultName : ""
        nameFilters: ["Zip files (*.zip)"]

        onAccepted: {
            let localPath = selectedFile.toString()

            if (localPath.startsWith("file://")) {
                localPath = localPath.substring(7)
            }

            if (localPath.match(/^\/[A-Za-z]:\//)) {
                localPath = localPath.substring(1)
            }

            if (!localPath.endsWith(".zip")) {
                localPath += ".zip"
            }

            ConnectionManager.downloadDirectory(remotePath, localPath)
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

    // Delete confirmation dialog
    Dialog {
        id: deleteConfirmDialog
        title: "Confirm Delete"
        property string itemPath: ""
        property bool isDirectory: false
        modal: true
        parent: Overlay.overlay
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

    ScrollView {
        id: scrollView
        anchors.fill: parent
        clip: true

        ListView {
            id: listView
            width: scrollView.width
            model: FileModel
            interactive: false

            // Deactivate for now as it conflcits with delegate
            //TapHandler {
            //    acceptedButtons: Qt.RightButton
            //    onTapped: {
            //        if (ConnectionManager.authenticated) {
            //            emptySpaceMenu.popup()
            //        }
            //    }
            //}

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
                    color: Material.primary

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        // Action buttons on the left
                        ToolButton {
                            icon.source: "qrc:/icons/plus.svg"
                            icon.width: 16
                            icon.height: 16
                            enabled: ConnectionManager.authenticated
                            onClicked: newFolderDialog.open()
                            ToolTip.visible: hovered
                            ToolTip.text: "New folder"
                            Material.roundedScale: Material.ExtraSmallScale
                        }

                        ToolButton {
                            icon.source: "qrc:/icons/upload.svg"
                            icon.width: 16
                            icon.height: 16
                            enabled: ConnectionManager.authenticated
                            onClicked: uploadDialog.open()
                            ToolTip.visible: hovered
                            ToolTip.text: "Upload files"
                            Material.roundedScale: Material.ExtraSmallScale
                        }

                        ToolButton {
                            icon.source: "qrc:/icons/refresh.svg"
                            icon.width: 16
                            icon.height: 16
                            enabled: ConnectionManager.authenticated
                            onClicked: {
                                ConnectionManager.listDirectory(FileModel.currentPath)
                            }
                            ToolTip.visible: hovered
                            ToolTip.text: "Refresh"
                            Material.roundedScale: Material.ExtraSmallScale
                        }

                        Rectangle {
                            Layout.preferredWidth: 1
                            Layout.preferredHeight: 24
                            color: Material.foreground
                            opacity: 0.2
                        }

                        // Breadcrumb path
                        Item {
                            id: path
                            Layout.fillWidth: true
                            implicitHeight: breadcrumbRow.implicitHeight
                            clip: true

                            Row {
                                id: measurementRow
                                visible: false
                                spacing: 6
                                height: parent.height

                                Button {
                                    text: ConnectionManager.serverName
                                    flat: true
                                    font.pixelSize: 13
                                    implicitWidth: contentItem.implicitWidth + 20
                                    Material.roundedScale: Material.ExtraSmallScale
                                }

                                Repeater {
                                    model: root.getPathSegments()

                                    Row {
                                        id: pathItem
                                        required property string modelData
                                        spacing: 6

                                        IconImage {
                                            source: "qrc:/icons/right.svg"
                                            sourceSize.width: 10
                                            sourceSize.height: 10
                                        }

                                        Button {
                                            text: pathItem.modelData
                                            flat: true
                                            font.pixelSize: 13
                                            implicitWidth: contentItem.implicitWidth + 20
                                            Material.roundedScale: Material.ExtraSmallScale
                                        }
                                    }
                                }
                            }

                            property bool needsEllipsis: measurementRow.implicitWidth > width - 20

                            Row {
                                id: breadcrumbRow
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6

                                Button {
                                    id: rootButton
                                    text: ConnectionManager.serverName
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

                                // Show ellipsis button if path is too long
                                Loader {
                                    active: path.needsEllipsis && root.getPathSegments().length > 1
                                    visible: active
                                    sourceComponent: Row {
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
                                            text: "..."
                                            flat: true
                                            font.pixelSize: 13
                                            implicitWidth: contentItem.implicitWidth + 20
                                            Material.roundedScale: Material.ExtraSmallScale
                                            opacity: ellipsisHover.hovered ? 1 : 0.7
                                            onClicked: hiddenPathsMenu.popup()

                                            HoverHandler {
                                                id: ellipsisHover
                                            }

                                            Menu {
                                                id: hiddenPathsMenu
                                                width: 200

                                                Instantiator {
                                                    model: root.getHiddenSegments()
                                                    delegate: MenuItem {
                                                        required property string modelData
                                                        required property int index
                                                        text: modelData
                                                        onClicked: {
                                                            ConnectionManager.listDirectory(root.getPathUpToHiddenIndex(index))
                                                        }
                                                    }
                                                    onObjectAdded: (index, object) => hiddenPathsMenu.insertItem(index, object)
                                                    onObjectRemoved: (index, object) => hiddenPathsMenu.removeItem(object)
                                                }
                                            }
                                        }
                                    }
                                }

                                // Show last segment if we have segments and need ellipsis
                                Loader {
                                    active: path.needsEllipsis && root.getPathSegments().length > 0
                                    visible: active
                                    sourceComponent: Row {
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
                                            text: root.getLastSegment()
                                            flat: true
                                            font.pixelSize: 13
                                            implicitWidth: contentItem.implicitWidth + 20
                                            Material.roundedScale: Material.ExtraSmallScale
                                            font.bold: true
                                            opacity: lastSegmentHover.hovered ? 1 : 0.7
                                            onClicked: {
                                                ConnectionManager.listDirectory(FileModel.currentPath)
                                            }

                                            HoverHandler {
                                                id: lastSegmentHover
                                            }
                                        }
                                    }
                                }

                                // Show all segments if path is not too long
                                Repeater {
                                    id: allSegmentsRepeater
                                    model: path.needsEllipsis ? [] : root.getPathSegments()

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
                                            font.bold: pathBtn.index === allSegmentsRepeater.count - 1
                                            opacity: pathBtn.index === allSegmentsRepeater.count - 1 || pathBtnHover.hovered ? 1 : 0.7
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
                            text: ""//"Parent Directory"
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
                        onDoubleTapped: {
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
                            if (delegateRoot.model.isDir) {
                                folderDownloadDialog.remotePath = delegateRoot.model.path
                                folderDownloadDialog.defaultName = delegateRoot.model.name + ".zip"
                                folderDownloadDialog.open()
                            } else {
                                fileDownloadDialog.remotePath = delegateRoot.model.path
                                fileDownloadDialog.defaultName = delegateRoot.model.name
                                fileDownloadDialog.open()
                            }
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
                            deleteConfirmDialog.itemPath = delegateRoot.model.path
                            deleteConfirmDialog.isDirectory = delegateRoot.model.isDir
                            deleteConfirmDialog.open()
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
                                Layout.preferredWidth: height
                                flat: true
                                onClicked: delContextMenu.popup()
                                Layout.alignment: Qt.AlignRight
                                opacity: (hoverHandler.hovered && root.draggedItemPath === "") ? 1 : 0
                                Material.roundedScale: Material.ExtraSmallScale
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
                                        let parentDirItem = headerItem.children[2]
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

    function shouldShowEllipsis() {
        let segments = getPathSegments()
        // Show ellipsis if we have more than 3 segments
        // This gives us: odzndrive > ... > current
        return segments.length > 3
    }

    function getHiddenSegments() {
        let segments = getPathSegments()
        if (segments.length <= 1) {
            return []
        }
        // Return all segments except the last one (which is shown)
        return segments.slice(0, -1)
    }

    function getPathUpToHiddenIndex(index) {
        let segments = getPathSegments()
        let pathParts = segments.slice(0, index + 1)
        return pathParts.join("/")
    }

    function getLastSegment() {
        let segments = getPathSegments()
        if (segments.length === 0) {
            return ""
        }
        return segments[segments.length - 1]
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
