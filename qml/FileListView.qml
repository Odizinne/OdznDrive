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
        for (let i = 0; i < FileModel.count; i++) {
            let item = FileModel.data(FileModel.index(i, 0), 257) // PathRole
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
        for (let i = 0; i < FileModel.count; i++) {
            let path = FileModel.data(FileModel.index(i, 0), 257) // PathRole
            if (isItemChecked(path)) {
                items.push({
                    path: path,
                    name: FileModel.data(FileModel.index(i, 0), 256), // NameRole
                    isDir: FileModel.data(FileModel.index(i, 0), 258) // IsDirRole
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

    // File upload dialog
    FileDialog {
        id: uploadDialog
        fileMode: FileDialog.OpenFiles
        onAccepted: {
            let files = []
            for (let i = 0; i < selectedFiles.length; i++) {
                let fileUrl = selectedFiles[i].toString()

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

    FileDialog {
        id: multiDownloadDialog
        fileMode: FileDialog.SaveFile
        property var itemPaths: []

        currentFile: "file:///" + root.getMultiDownloadDefaultName()
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

            console.log("Multi-download to:", localPath, "Paths:", itemPaths)
        }
    }

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

    Dialog {
        id: multiDeleteConfirmDialog
        title: "Confirm Delete"
        property int itemCount: 0
        modal: true
        parent: Overlay.overlay
        anchors.centerIn: parent

        Label {
            text: "Are you sure you want to delete " + multiDeleteConfirmDialog.itemCount + " item(s)?"
        }

        standardButtons: Dialog.Yes | Dialog.No

        onAccepted: {
            let items = root.getCheckedItems()
            for (let i = 0; i < items.length; i++) {
                if (items[i].isDir) {
                    ConnectionManager.deleteDirectory(items[i].path)
                } else {
                    ConnectionManager.deleteFile(items[i].path)
                }
            }
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

    Loader {
        anchors.fill: parent
        sourceComponent: UserSettings.listView ? listViewComponent : tileViewComponent
    }

    Component {
        id: listViewComponent

        ScrollView {
            id: scrollView
            clip: true

            ListView {
                id: listView
                width: scrollView.width
                model: FileModel
                interactive: false

                headerPositioning: ListView.OverlayHeader

                header: Item {
                    width: listView.width
                    height: 45 + 45 + (FileModel.canGoUp ? 50 : 0)
                    z: 2

                    Rectangle {
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
                                onClicked: uploadDialog.open()
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
                                    ConnectionManager.listDirectory(FileModel.currentPath)
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
                                    if (items.length === 1) {
                                        if (items[0].isDir) {
                                            folderDownloadDialog.remotePath = items[0].path
                                            folderDownloadDialog.defaultName = items[0].name + ".zip"
                                            folderDownloadDialog.open()
                                        } else {
                                            fileDownloadDialog.remotePath = items[0].path
                                            fileDownloadDialog.defaultName = items[0].name
                                            fileDownloadDialog.open()
                                        }
                                    } else {
                                        multiDownloadDialog.itemPaths = root.getCheckedPaths()
                                        multiDownloadDialog.open()
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

                    Rectangle {
                        id: columnHeader
                        width: parent.width
                        height: 45
                        anchors.top: breadcrumbBar.bottom
                        color: Constants.listHeaderColor

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 10

                            CheckBox {
                                id: headerCheckbox
                                Layout.preferredWidth: 30
                                checked: root.checkedCount > 0 && root.checkedCount === FileModel.count
                                tristate: root.checkedCount > 0 && root.checkedCount < FileModel.count
                                checkState: {
                                    if (root.checkedCount === 0) return Qt.Unchecked
                                    if (root.checkedCount === FileModel.count) return Qt.Checked
                                    return Qt.PartiallyChecked
                                }
                                onClicked: {
                                    if (root.checkedCount === FileModel.count) {
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

                            Item {
                                Layout.preferredWidth: 30
                            }

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
    }

    Component {
        id: tileViewComponent

        ScrollView {
            id: tileScrollView
            clip: true

            Item {
                width: tileScrollView.width
                implicitHeight: breadcrumbBar.height + tileGrid.y + tileGrid.height + 10

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

                        for (let i = 0; i < FileModel.count; i++) {
                            append({
                                "name": FileModel.data(FileModel.index(i, 0), 257),        // NameRole
                                "path": FileModel.data(FileModel.index(i, 0), 258),        // PathRole
                                "isDir": FileModel.data(FileModel.index(i, 0), 259),       // IsDirRole
                                "size": FileModel.data(FileModel.index(i, 0), 260),        // SizeRole
                                "modified": FileModel.data(FileModel.index(i, 0), 261),    // ModifiedRole
                                "previewPath": FileModel.data(FileModel.index(i, 0), 262) || "",  // PreviewPathRole
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

                Rectangle {
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
                            onClicked: uploadDialog.open()
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
                                ConnectionManager.listDirectory(FileModel.currentPath)
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
                                if (items.length === 1) {
                                    if (items[0].isDir) {
                                        folderDownloadDialog.remotePath = items[0].path
                                        folderDownloadDialog.defaultName = items[0].name + ".zip"
                                        folderDownloadDialog.open()
                                    } else {
                                        fileDownloadDialog.remotePath = items[0].path
                                        fileDownloadDialog.defaultName = items[0].name
                                        fileDownloadDialog.open()
                                    }
                                } else {
                                    multiDownloadDialog.itemPaths = root.getCheckedPaths()
                                    multiDownloadDialog.open()
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
                            id: tilePath
                            Layout.fillWidth: true
                            implicitHeight: tileBreadcrumbRow.implicitHeight
                            clip: true

                            Row {
                                id: tileMeasurementRow
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
                                        id: tilePathItem
                                        required property string modelData
                                        spacing: 6

                                        IconImage {
                                            source: "qrc:/icons/right.svg"
                                            sourceSize.width: 10
                                            sourceSize.height: 10
                                        }

                                        Button {
                                            text: tilePathItem.modelData
                                            flat: true
                                            font.pixelSize: 13
                                            implicitWidth: contentItem.implicitWidth + 20
                                            Material.roundedScale: Material.ExtraSmallScale
                                        }
                                    }
                                }
                            }

                            property bool needsEllipsis: tileMeasurementRow.implicitWidth > width - 20

                            Row {
                                id: tileBreadcrumbRow
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6

                                Button {
                                    text: ConnectionManager.serverName
                                    flat: true
                                    font.pixelSize: 13
                                    implicitWidth: contentItem.implicitWidth + 20
                                    onClicked: ConnectionManager.listDirectory("")
                                    font.bold: root.getPathSegments().length === 0
                                    opacity: root.getPathSegments().length === 0 || tileRootHover.hovered ? 1 : 0.7
                                    Material.roundedScale: Material.ExtraSmallScale

                                    HoverHandler {
                                        id: tileRootHover
                                    }
                                }

                                Loader {
                                    active: tilePath.needsEllipsis && root.getPathSegments().length > 1
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
                                            opacity: tileEllipsisHover.hovered ? 1 : 0.7
                                            onClicked: tileHiddenPathsMenu.popup()

                                            HoverHandler {
                                                id: tileEllipsisHover
                                            }

                                            Menu {
                                                id: tileHiddenPathsMenu
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
                                                    onObjectAdded: (index, object) => tileHiddenPathsMenu.insertItem(index, object)
                                                    onObjectRemoved: (index, object) => tileHiddenPathsMenu.removeItem(object)
                                                }
                                            }
                                        }
                                    }
                                }

                                Loader {
                                    active: tilePath.needsEllipsis && root.getPathSegments().length > 0
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
                                            opacity: tileLastSegmentHover.hovered ? 1 : 0.7
                                            onClicked: {
                                                ConnectionManager.listDirectory(FileModel.currentPath)
                                            }

                                            HoverHandler {
                                                id: tileLastSegmentHover
                                            }
                                        }
                                    }
                                }

                                Repeater {
                                    id: tileAllSegmentsRepeater
                                    model: tilePath.needsEllipsis ? [] : root.getPathSegments()

                                    Row {
                                        id: tilePathBtn
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
                                            text: tilePathBtn.modelData
                                            flat: true
                                            font.pixelSize: 13
                                            implicitWidth: contentItem.implicitWidth + 20
                                            Material.roundedScale: Material.ExtraSmallScale
                                            font.bold: tilePathBtn.index === tileAllSegmentsRepeater.count - 1
                                            opacity: tilePathBtn.index === tileAllSegmentsRepeater.count - 1 || tilePathBtnHover.hovered ? 1 : 0.7
                                            onClicked: {
                                                ConnectionManager.listDirectory(root.getPathUpToIndex(tilePathBtn.index))
                                            }

                                            HoverHandler {
                                                id: tilePathBtnHover
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        ToolButton {
                            icon.source: UserSettings.listView ? "qrc:/icons/tiles.svg" : "qrc:/icons/list.svg"
                            icon.width: 16
                            icon.height: 16
                            onClicked: UserSettings.listView = !UserSettings.listView
                            ToolTip.visible: hovered
                            ToolTip.text: UserSettings.listView ? "Tile view" : "List view"
                            Material.roundedScale: Material.ExtraSmallScale
                        }
                    }
                }

                GridView {
                    id: tileGrid
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: breadcrumbBar.bottom
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

                            Behavior on border.color {
                                ColorAnimation { duration: 150 }
                            }

                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 0

                                Item {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: parent.height * (2/3) - 1

                                    CheckBox {
                                        visible: !tileDelegateRoot.isParentItem
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.margins: 4
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
                                        anchors.centerIn: parent
                                        width: parent.width - 16
                                        height: parent.height - 16
                                        fillMode: Image.PreserveAspectFit
                                        cache: false
                                        asynchronous: true
                                        visible: !tileDelegateRoot.isParentItem &&
                                                 !tileDelegateRoot.itemIsDir &&
                                                 tileDelegateRoot.model.previewPath !== "" &&
                                                 status === Image.Ready
                                        source: tileDelegateRoot.model.previewPath || ""
                                        smooth: true
                                        mipmap: true
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 1
                                    color: Constants.borderColor
                                }

                                Item {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: parent.height * (1/3)
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
                                        font.pixelSize: 12
                                        wrapMode: Text.NoWrap
                                        opacity: tileDelegateRoot.isParentItem ? 0.7 : 1.0
                                    }
                                }
                            }

                            HoverHandler {
                                id: tileHoverHandler
                            }

                            DragHandler {
                                id: tileDragHandler
                                target: null
                                dragThreshold: 15
                                enabled: !tileDelegateRoot.isParentItem

                                onActiveChanged: {
                                    if (active) {
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
                                    if (tileDelegateRoot.isParentItem) {
                                        ConnectionManager.listDirectory(FileModel.getParentPath())
                                    } else if (tileDelegateRoot.itemIsDir) {
                                        ConnectionManager.listDirectory(tileDelegateRoot.itemPath)
                                    }
                                }
                            }

                            TapHandler {
                                acceptedButtons: Qt.RightButton
                                enabled: !tileDelegateRoot.isParentItem
                                onTapped: {
                                    tileContextMenu.popup()
                                }
                            }

                            Menu {
                                id: tileContextMenu
                                width: 200
                                MenuItem {
                                    text: tileDelegateRoot.itemName
                                    enabled: false
                                }

                                MenuItem {
                                    text: "Download"
                                    icon.source: "qrc:/icons/download.svg"
                                    icon.width: 16
                                    icon.height: 16
                                    onClicked: {
                                        if (tileDelegateRoot.itemIsDir) {
                                            folderDownloadDialog.remotePath = tileDelegateRoot.itemPath
                                            folderDownloadDialog.defaultName = tileDelegateRoot.itemName + ".zip"
                                            folderDownloadDialog.open()
                                        } else {
                                            fileDownloadDialog.remotePath = tileDelegateRoot.itemPath
                                            fileDownloadDialog.defaultName = tileDelegateRoot.itemName
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
                                        deleteConfirmDialog.itemPath = tileDelegateRoot.itemPath
                                        deleteConfirmDialog.isDirectory = tileDelegateRoot.itemIsDir
                                        deleteConfirmDialog.open()
                                    }
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
