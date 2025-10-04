pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Material
import QtQuick.Controls.impl
import QtQuick.Layouts
import Odizinne.OdznDrive
import Qt5Compat.GraphicalEffects

Rectangle {
    id: root
    color: Constants.backgroundColor

    // Track checked items
    property var checkedItems: ({})
    property int checkedCount: 0

    function isItemChecked(path) {
        return checkedItems[path] === true
    }

    function toggleItemChecked(path) {
        let newChecked = Object.assign({}, checkedItems)
        if (newChecked[path]) {
            delete newChecked[path]
        } else {
            newChecked[path] = true
        }
        checkedItems = newChecked
        updateCheckedCount()
    }

    function checkAll() {
        let newChecked = {}
        for (let i = 0; i < FilterProxyModel.rowCount(); i++) {
            let item = FilterProxyModel.data(FilterProxyModel.index(i, 0), 258) // PathRole
            newChecked[item] = true
        }
        checkedItems = newChecked
        updateCheckedCount()
    }

    function uncheckAll() {
        checkedItems = {}
        updateCheckedCount()
    }

    function updateCheckedCount() {
        let count = 0
        for (let key in checkedItems) {
            if (checkedItems[key]) {
                count++
            }
        }
        checkedCount = count
    }

    function getCheckedPaths() {
        let paths = []
        for (let key in checkedItems) {
            if (checkedItems[key]) {
                paths.push(key)
            }
        }
        return paths
    }

    function getCheckedItems() {
        let items = []
        for (let i = 0; i < FilterProxyModel.rowCount(); i++) {
            let idx = FilterProxyModel.index(i, 0)
            let path = FilterProxyModel.data(idx, 258) // PathRole
            if (isItemChecked(path)) {
                items.push({
                               path: path,
                               name: FilterProxyModel.data(idx, 257), // NameRole
                               isDir: FilterProxyModel.data(idx, 259) // IsDirRole
                           })
            }
        }
        return items
    }

    // Clear selection when directory changes
    Connections {
        target: FileModel
        function onCurrentPathChanged() {
            root.uncheckAll()
        }
    }

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

    function openUploadDialog() {
        let files = FileDialogHelper.openFiles("Select Files to Upload")
        if (files.length > 0) {
            ConnectionManager.uploadFiles(files, FileModel.currentPath)
        }
    }

    function openFileDownloadDialog(remotePath, defaultName) {
        let localPath = FileDialogHelper.saveFile("Save File", defaultName, "")
        if (localPath !== "") {
            ConnectionManager.downloadFile(remotePath, localPath)
        }
    }

    function openFolderDownloadDialog(remotePath, defaultName) {
        let localPath = FileDialogHelper.saveFile("Save Folder as Zip", defaultName, "Zip files (*.zip)")
        if (localPath !== "") {
            if (!localPath.endsWith(".zip")) {
                localPath += ".zip"
            }
            ConnectionManager.downloadDirectory(remotePath, localPath)
        }
    }

    function openMultiDownloadDialog(itemPaths) {
        let localPath = FileDialogHelper.saveFile("Save as Zip", root.getMultiDownloadDefaultName(), "Zip files (*.zip)")
        if (localPath !== "") {
            if (!localPath.endsWith(".zip")) {
                localPath += ".zip"
            }

            let fileName = localPath.split('/').pop().split('\\').pop()
            let zipName = fileName.endsWith('.zip') ? fileName.slice(0, -4) : fileName

            ConnectionManager.downloadMultiple(itemPaths, localPath, zipName)
            root.uncheckAll()
        }
    }

    CustomDialog {
        id: newFolderDialog
        title: "Create New Folder"
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

    CustomDialog {
        id: deleteConfirmDialog
        title: "Confirm Delete"
        property string itemPath: ""
        property bool isDirectory: false
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

    CustomDialog {
        id: multiDeleteConfirmDialog
        title: "Confirm Delete"
        property int itemCount: 0
        parent: Overlay.overlay
        anchors.centerIn: parent

        Label {
            text: "Are you sure you want to delete " + multiDeleteConfirmDialog.itemCount + " item(s)?"
        }

        standardButtons: Dialog.Yes | Dialog.No

        onAccepted: {
            let paths = root.getCheckedPaths()
            ConnectionManager.deleteMultiple(paths)
            root.uncheckAll()
        }
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

    component ItemContextMenu: Menu {
        id: contextMenu
        width: 200

        required property string itemPath
        required property string itemName
        required property bool itemIsDir

        MenuItem {
            text: contextMenu.itemName
            enabled: false
        }

        MenuItem {
            text: "Download"
            icon.source: "qrc:/icons/download.svg"
            icon.width: 16
            icon.height: 16
            onClicked: {
                if (contextMenu.itemIsDir) {
                    root.openFolderDownloadDialog(items[0].path, items[0].name + ".zip")
                } else {
                    root.openFileDownloadDialog(contextMenu.itemPath, contextMenu.itemName)
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
                deleteConfirmDialog.itemPath = contextMenu.itemPath
                deleteConfirmDialog.isDirectory = contextMenu.itemIsDir
                deleteConfirmDialog.open()
            }
        }
    }

    component EmptySpaceMenu: Menu {
        width: 200

        MenuItem {
            text: "New Folder"
            icon.source: "qrc:/icons/plus.svg"
            icon.width: 16
            icon.height: 16
            enabled: ConnectionManager.authenticated
            onClicked: newFolderDialog.open()
        }

        MenuItem {
            text: "Upload Files"
            icon.source: "qrc:/icons/upload.svg"
            icon.width: 16
            icon.height: 16
            enabled: ConnectionManager.authenticated
            onClicked: root.openUploadDialog()
        }

        MenuItem {
            text: "Refresh"
            icon.source: "qrc:/icons/refresh.svg"
            icon.width: 16
            icon.height: 16
            enabled: ConnectionManager.authenticated
            onClicked: ConnectionManager.listDirectory(FileModel.currentPath, UserSettings.foldersFirst)
        }
    }

    // Shared Breadcrumb Bar Component
    component BreadcrumbBar: Rectangle {
        id: breadcrumbBar
        width: parent.width
        height: 45
        color: Material.primary

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 3
            anchors.rightMargin: 10
            spacing: 8

            ToolButton {
                visible: root.checkedCount === 0
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
                visible: root.checkedCount === 0
                icon.source: "qrc:/icons/upload.svg"
                icon.width: 16
                icon.height: 16
                enabled: ConnectionManager.authenticated
                onClicked: root.openUploadDialog()
                ToolTip.visible: hovered
                ToolTip.text: "Upload files"
                Material.roundedScale: Material.ExtraSmallScale
            }

            ToolButton {
                visible: root.checkedCount === 0
                icon.source: "qrc:/icons/refresh.svg"
                icon.width: 16
                icon.height: 16
                enabled: ConnectionManager.authenticated
                onClicked: {
                    ConnectionManager.listDirectory(FileModel.currentPath, UserSettings.foldersFirst)
                }
                ToolTip.visible: hovered
                ToolTip.text: "Refresh"
                Material.roundedScale: Material.ExtraSmallScale
            }

            ToolButton {
                visible: root.checkedCount > 0
                icon.source: "qrc:/icons/download.svg"
                icon.width: 16
                icon.height: 16
                enabled: ConnectionManager.authenticated
                onClicked: {
                    let items = root.getCheckedItems()

                    // If only 1 item, treat as single download
                    if (items.length === 1) {
                        if (items[0].isDir) {
                            root.openFolderDownloadDialog(items[0].path, items[0].name + ".zip")
                        } else {
                            root.openFileDownloadDialog(contextMenu.itemPath, contextMenu.itemName)
                        }
                    } else {
                        root.openMultiDownloadDialog(root.getCheckedPaths())
                    }
                }
                ToolTip.visible: hovered
                ToolTip.text: root.checkedCount === 1 ? "Download" : "Download as zip"
                Material.roundedScale: Material.ExtraSmallScale
            }

            ToolButton {
                visible: root.checkedCount > 0
                icon.source: "qrc:/icons/delete.svg"
                icon.width: 16
                icon.height: 16
                enabled: ConnectionManager.authenticated
                onClicked: {
                    multiDeleteConfirmDialog.itemCount = root.checkedCount
                    multiDeleteConfirmDialog.open()
                }
                ToolTip.visible: hovered
                ToolTip.text: "Delete selected"
                Material.roundedScale: Material.ExtraSmallScale
            }

            Label {
                visible: root.checkedCount > 0
                text: root.checkedCount + (root.checkedCount === 1 ? " item selected" : " items selected")
                opacity: 0.7
                Layout.rightMargin: 4
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: 24
                color: Material.foreground
                opacity: 0.2
            }

            Item {
                id: pathItem
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
                            id: pathMeasureItem
                            required property string modelData
                            spacing: 6

                            IconImage {
                                source: "qrc:/icons/right.svg"
                                sourceSize.width: 10
                                sourceSize.height: 10
                            }

                            Button {
                                text: pathMeasureItem.modelData
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
                        onClicked: ConnectionManager.listDirectory("", UserSettings.foldersFirst)
                        font.bold: root.getPathSegments().length === 0
                        opacity: root.getPathSegments().length === 0 || rootHover.hovered ? 1 : 0.7
                        Material.roundedScale: Material.ExtraSmallScale

                        HoverHandler {
                            id: rootHover
                        }
                    }

                    Loader {
                        active: pathItem.needsEllipsis && root.getPathSegments().length > 1
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
                                                ConnectionManager.listDirectory(root.getPathUpToHiddenIndex(index), UserSettings.foldersFirst)
                                            }
                                        }
                                        onObjectAdded: (index, object) => hiddenPathsMenu.insertItem(index, object)
                                        onObjectRemoved: (index, object) => hiddenPathsMenu.removeItem(object)
                                    }
                                }
                            }
                        }
                    }

                    Loader {
                        active: pathItem.needsEllipsis && root.getPathSegments().length > 0
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
                                    ConnectionManager.listDirectory(FileModel.currentPath, UserSettings.foldersFirst)
                                }

                                HoverHandler {
                                    id: lastSegmentHover
                                }
                            }
                        }
                    }

                    Repeater {
                        id: allSegmentsRepeater
                        model: pathItem.needsEllipsis ? [] : root.getPathSegments()

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
                                    ConnectionManager.listDirectory(root.getPathUpToIndex(pathBtn.index), UserSettings.foldersFirst)
                                }

                                HoverHandler {
                                    id: pathBtnHover
                                }
                            }
                        }
                    }
                }
            }

            ToolButton {
                icon.source: UserSettings.listView ? "qrc:/icons/grid.svg" : "qrc:/icons/list.svg"
                icon.width: 16
                icon.height: 16
                onClicked: UserSettings.listView = !UserSettings.listView
                ToolTip.visible: hovered
                ToolTip.text: UserSettings.listView ? "Tile view" : "List view"
                Material.roundedScale: Material.ExtraSmallScale
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        BreadcrumbBar {
            Layout.fillWidth: true
        }

        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            sourceComponent: UserSettings.listView ? listViewComponent : tileViewComponent
        }
    }

    Component {
        id: listViewComponent

        ScrollView {
            id: scrollView
            clip: true
            ContextMenu.menu: EmptySpaceMenu {}

            ListView {
                id: listView
                width: scrollView.width
                model: FilterProxyModel
                interactive: false

                headerPositioning: ListView.OverlayHeader
                header: Item {
                    width: listView.width
                    height: 45 + (FileModel.canGoUp ? 50 : 0)
                    z: 2

                    Rectangle {
                        id: columnHeader
                        width: parent.width
                        height: 45
                        color: Constants.listHeaderColor

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 10

                            CheckBox {
                                id: headerCheckbox
                                Layout.preferredWidth: 30
                                checked: root.checkedCount > 0 && root.checkedCount === FilterProxyModel.rowCount()
                                tristate: root.checkedCount > 0 && root.checkedCount < FilterProxyModel.rowCount()
                                checkState: {
                                    if (root.checkedCount === 0) return Qt.Unchecked
                                    if (root.checkedCount === FilterProxyModel.rowCount()) return Qt.Checked
                                    return Qt.PartiallyChecked
                                }
                                onClicked: {
                                    if (root.checkedCount === FilterProxyModel.rowCount()) {
                                        root.uncheckAll()
                                    } else {
                                        root.checkAll()
                                    }
                                }
                            }

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
                        property string itemPath: FileModel.canGoUp ? FileModel.getParentPath() : ""
                        property string itemName: ".."

                        ContextMenu.menu: Menu {
                            width: 200

                            MenuItem {
                                text: "Navigate Up"
                                icon.source: "qrc:/icons/folder.svg"
                                icon.width: 16
                                icon.height: 16
                                onClicked: {
                                    ConnectionManager.listDirectory(FileModel.getParentPath(), UserSettings.foldersFirst)
                                }
                            }
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

                            Item {
                                Layout.preferredWidth: 30
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Image {
                                    Layout.preferredWidth: 24
                                    Layout.preferredHeight: 24
                                    source: "qrc:/icons/folder.svg"
                                    fillMode: Image.PreserveAspectFit
                                }

                                Label {
                                    text: ".."
                                    Layout.fillWidth: true
                                    font.bold: true
                                    opacity: 0.7
                                }
                            }

                            Label {
                                text: "-"
                                Layout.preferredWidth: 100
                                opacity: 0.7
                            }

                            Label {
                                text: ""
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
                                ConnectionManager.listDirectory(FileModel.getParentPath(), UserSettings.foldersFirst)
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
                    ItemContextMenu {
                        id: delContextMenu
                        itemPath: delegateRoot.model.path
                        itemName: delegateRoot.model.name
                        itemIsDir: delegateRoot.model.isDir
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

                            CheckBox {
                                Layout.preferredWidth: 30
                                checked: root.isItemChecked(delegateRoot.model.path)
                                onClicked: {
                                    root.toggleItemChecked(delegateRoot.model.path)
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Image {
                                    Layout.preferredWidth: 24
                                    Layout.preferredHeight: 24
                                    fillMode: Image.PreserveAspectFit
                                    cache: false
                                    asynchronous: true
                                    source: {
                                        if (delegateRoot.model.isDir) {
                                            return "qrc:/icons/folder.svg"
                                        }
                                        if (delegateRoot.model.previewPath) {
                                            return delegateRoot.model.previewPath
                                        }
                                        return "qrc:/icons/file.svg"
                                    }

                                    // Fallback for failed preview loads
                                    onStatusChanged: {
                                        if (status === Image.Error && !delegateRoot.model.isDir) {
                                            source = "qrc:/icons/file.svg"
                                        }
                                    }
                                }

                                Label {
                                    text: delegateRoot.model.name
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
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

                                    if (FileModel.canGoUp) {
                                        let headerItem = listView.headerItem
                                        if (headerItem) {
                                            let parentDirItem = headerItem.children[1]
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
                            onTapped: root.toggleItemChecked(delegateRoot.model.path)
                            onDoubleTapped: {
                                if (delegateRoot.model.isDir) {
                                    ConnectionManager.listDirectory(delegateRoot.model.path, UserSettings.foldersFirst)
                                }
                            }
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
            }
        }
    }

    Component {
        id: tileViewComponent

        ScrollView {
            id: tileScrollView
            clip: true
            ContextMenu.menu: EmptySpaceMenu {}
            // Add connections for thumbnail updates
            Connections {
                target: FileModel

                function onDataChanged(topLeft, bottomRight, roles) {
                    // When FileModel data changes (thumbnail arrives), refresh tile model
                    if (roles.length === 0 || roles.includes(262)) { // PreviewPathRole = 262
                        let startRow = topLeft.row
                        let endRow = bottomRight.row

                        for (let row = startRow; row <= endRow; row++) {
                            let path = FileModel.data(FileModel.index(row, 0), 258) // PathRole
                            let previewPath = FileModel.data(FileModel.index(row, 0), 262) // PreviewPathRole

                            // Find and update in tile model
                            for (let i = 0; i < tileModel.count; i++) {
                                if (tileModel.get(i).path === path && !tileModel.get(i).isParent) {
                                    tileModel.setProperty(i, "previewPath", previewPath)
                                    break
                                }
                            }
                        }
                    }
                }
            }

            Item {
                width: tileScrollView.width
                implicitHeight: tileGrid.y + tileGrid.height + 10

                ListModel {
                    id: tileModel

                    function refresh() {
                        clear()

                        if (FileModel.canGoUp) {
                            append({
                                       "name": "..",
                                       "path": FileModel.getParentPath(),
                                       "isDir": true,
                                       "size": 0,
                                       "modified": "",
                                       "previewPath": "",
                                       "isParent": true
                                   })
                        }

                        for (let i = 0; i < FilterProxyModel.rowCount(); i++) {
                            append({
                                       "name": FilterProxyModel.data(FilterProxyModel.index(i, 0), 257),        // NameRole
                                       "path": FilterProxyModel.data(FilterProxyModel.index(i, 0), 258),        // PathRole
                                       "isDir": FilterProxyModel.data(FilterProxyModel.index(i, 0), 259),       // IsDirRole
                                       "size": FilterProxyModel.data(FilterProxyModel.index(i, 0), 260),        // SizeRole
                                       "modified": FilterProxyModel.data(FilterProxyModel.index(i, 0), 261),    // ModifiedRole
                                       "previewPath": FilterProxyModel.data(FilterProxyModel.index(i, 0), 262) || "",  // PreviewPathRole
                                       "isParent": false
                                   })
                        }
                    }

                    Component.onCompleted: refresh()
                }

                Connections {
                    target: FileModel
                    function onCurrentPathChanged() {
                        tileModel.refresh()
                    }
                    function onCountChanged() {
                        tileModel.refresh()
                    }
                }

                Connections {
                    target: FilterProxyModel
                    function onFilterTextChanged() {
                        tileModel.refresh()
                    }
                }

                GridView {
                    id: tileGrid
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        leftMargin: 10
                        rightMargin: 10
                        topMargin: 10
                    }

                    height: Math.ceil(count / Math.floor(width / cellWidth)) * cellHeight
                    interactive: false

                    property int minCellWidth: 210
                    property int columns: Math.max(1, Math.floor(width / minCellWidth))
                    property real cellSize: Math.floor(width / columns)
                    cellWidth: cellSize
                    cellHeight: cellSize

                    model: tileModel

                    delegate: Item {
                        id: tileDelegateRoot
                        width: tileGrid.cellWidth
                        height: tileGrid.cellHeight
                        required property var model
                        required property int index

                        property string itemPath: model.path
                        property string itemName: model.name
                        property bool itemIsDir: model.isDir
                        property bool isParentItem: model.isParent

                        // Add hover timer for tooltip
                        Timer {
                            id: tooltipTimer
                            interval: 2000
                            repeat: false
                            onTriggered: {
                                if (!tileDelegateRoot.isParentItem && tileHoverHandler.hovered) {
                                    tileTooltip.visible = true
                                }
                            }
                        }

                        ToolTip {
                            id: tileTooltip
                            visible: false
                            delay: 0
                            timeout: -1
                            x: tileHoverHandler.point.position.x + 15
                            y: tileHoverHandler.point.position.y + 15
                            text: {
                                if (tileDelegateRoot.isParentItem) return ""

                                let sizeText = tileDelegateRoot.itemIsDir ? "-" : root.formatSize(tileDelegateRoot.model.size)
                                let dateText = root.formatDate(tileDelegateRoot.model.modified)

                                return "Size: " + sizeText + "\nModified: " + dateText
                            }
                        }

                        Rectangle {
                            id: tileRect
                            anchors.fill: parent
                            anchors.margins: 5
                            color: {
                                if (tileHoverHandler.hovered) {
                                    return Constants.alternateRowColor
                                }
                                return "transparent"
                            }
                            border.width: 1
                            border.color: {
                                if (root.currentDropTarget === tileDelegateRoot && tileDelegateRoot.itemIsDir && root.draggedItemPath !== tileDelegateRoot.itemPath) {
                                    return Material.accent
                                }
                                if (!tileDelegateRoot.isParentItem && root.isItemChecked(tileDelegateRoot.itemPath)) {
                                    return Material.accent
                                }
                                return Constants.borderColor
                            }
                            radius: 4

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 0

                                Item {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: parent.height * (3/4) - 1

                                    CheckBox {
                                        visible: !tileDelegateRoot.isParentItem
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.topMargin: -3
                                        z: 1
                                        checked: root.isItemChecked(tileDelegateRoot.itemPath)
                                        onClicked: {
                                            root.toggleItemChecked(tileDelegateRoot.itemPath)
                                        }
                                    }

                                    Image {
                                        id: iconImage
                                        anchors.centerIn: parent
                                        width: 64
                                        height: 64
                                        sourceSize.width: 64
                                        sourceSize.height: 64
                                        fillMode: Image.PreserveAspectFit
                                        visible: !previewImage.visible
                                        source: {
                                            if (tileDelegateRoot.isParentItem || tileDelegateRoot.itemIsDir) {
                                                return "qrc:/icons/folder.svg"
                                            }
                                            return "qrc:/icons/file.svg"
                                        }
                                        smooth: true
                                    }

                                    Image {
                                        id: previewImage
                                        anchors.fill: parent
                                        anchors.topMargin: 1
                                        anchors.leftMargin: 1
                                        anchors.rightMargin: 1
                                        anchors.bottomMargin: -1
                                        fillMode: Image.PreserveAspectCrop
                                        cache: false
                                        asynchronous: true
                                        visible: !tileDelegateRoot.isParentItem &&
                                                 !tileDelegateRoot.itemIsDir &&
                                                 tileDelegateRoot.model.previewPath !== "" &&
                                                 status === Image.Ready
                                        source: tileDelegateRoot.model.previewPath || ""
                                        smooth: true
                                        mipmap: true

                                        layer.enabled: true
                                        layer.effect: OpacityMask {
                                            maskSource: Rectangle {
                                                width: previewImage.width
                                                height: previewImage.height
                                                topLeftRadius: 4
                                                topRightRadius: 4
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 1
                                    color: Constants.borderColor
                                }

                                Item {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: parent.height * (1/4)
                                    Layout.leftMargin: 8
                                    Layout.rightMargin: 8
                                    Label {
                                        anchors.fill: parent
                                        anchors.bottomMargin: 5
                                        text: tileDelegateRoot.itemName
                                        elide: Text.ElideMiddle
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        font.bold: tileDelegateRoot.isParentItem ? true : root.isItemChecked(tileDelegateRoot.itemPath)
                                        font.pixelSize: 13
                                        wrapMode: Text.NoWrap
                                        opacity: tileDelegateRoot.isParentItem ? 0.7 : 1.0
                                    }
                                }
                            }

                            HoverHandler {
                                id: tileHoverHandler
                                onHoveredChanged: {
                                    if (hovered) {
                                        tooltipTimer.restart()
                                    } else {
                                        tooltipTimer.stop()
                                        tileTooltip.visible = false
                                    }
                                }
                            }

                            DragHandler {
                                id: tileDragHandler
                                target: null
                                dragThreshold: 15
                                enabled: !tileDelegateRoot.isParentItem

                                onActiveChanged: {
                                    if (active) {
                                        tooltipTimer.stop()
                                        tileTooltip.visible = false
                                        root.draggedItemPath = tileDelegateRoot.itemPath
                                        root.draggedItemName = tileDelegateRoot.itemName
                                        dragLabel.text = "Move " + tileDelegateRoot.itemName
                                        dragIndicator.visible = true
                                    } else {
                                        dragIndicator.visible = false

                                        if (root.currentDropTarget) {
                                            let targetPath = root.currentDropTarget.itemPath

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
                                        let globalPos = tileRect.mapToItem(null, centroid.position.x, centroid.position.y)
                                        dragIndicator.x = globalPos.x + 10
                                        dragIndicator.y = globalPos.y + 10

                                        let gridPos = tileRect.mapToItem(tileGrid, centroid.position.x, centroid.position.y)

                                        root.currentDropTarget = null

                                        for (let i = 0; i < tileGrid.count; i++) {
                                            let item = tileGrid.itemAtIndex(i)
                                            if (item) {
                                                let itemPos = item.mapFromItem(tileGrid, gridPos.x, gridPos.y)
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
                                onTapped: {
                                    if (!tileDelegateRoot.isParentItem) {
                                        root.toggleItemChecked(tileDelegateRoot.itemPath)
                                    }
                                }
                                onDoubleTapped: {
                                    tooltipTimer.stop()
                                    tileTooltip.visible = false
                                    if (tileDelegateRoot.isParentItem) {
                                        ConnectionManager.listDirectory(FileModel.getParentPath(), UserSettings.foldersFirst)
                                    } else if (tileDelegateRoot.itemIsDir) {
                                        ConnectionManager.listDirectory(tileDelegateRoot.itemPath, UserSettings.foldersFirst)
                                    }
                                }
                            }

                            ContextMenu.menu: tileDelegateRoot.isParentItem ? parentItemMenu : tileContextMenu

                            Menu {
                                id: parentItemMenu
                                width: 200

                                MenuItem {
                                    text: "Navigate Up"
                                    icon.source: "qrc:/icons/folder.svg"
                                    icon.width: 16
                                    icon.height: 16
                                    onClicked: {
                                        ConnectionManager.listDirectory(FileModel.getParentPath(), UserSettings.foldersFirst)
                                    }
                                }
                            }

                            ItemContextMenu {
                                id: tileContextMenu
                                itemPath: tileDelegateRoot.itemPath
                                itemName: tileDelegateRoot.itemName
                                itemIsDir: tileDelegateRoot.itemIsDir
                            }
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

    function getHiddenSegments() {
        let segments = getPathSegments()
        if (segments.length <= 1) {
            return []
        }
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

    function getMultiDownloadDefaultName() {
        let now = new Date()
        let dateStr = Qt.formatDateTime(now, "yyyy-MM-dd_HH-mm-ss")
        return "OdznDrive_Download_" + dateStr + ".zip"
    }
}
