pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Material
import QtQuick.Layouts
import Odizinne.OdznDrive

ColumnLayout {
    id: fileListView
    spacing: 0
    signal requestRename(string path, string name)
    signal requestDelete(string path, bool isDir)
    signal requestPreview(string path, string name)
    signal setDragIndicatorX(int x)
    signal setDragIndicatorY(int y)
    signal setDragIndicatorVisible(bool visible)
    signal setDragIndicatorText(string text)

    function setScrollViewMenu(menu) {
        scrollView.ContextMenu.menu = menu
    }

    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 55

        Rectangle {
            id: columnHeader
            width: parent.width
            height: 55
            clip: true
            color: Constants.backgroundColor

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10 + (scrollView.ScrollBar.vertical.policy === ScrollBar.AlwaysOn ? 12 + 8 : 12)
                spacing: 10

                CheckBox {
                    id: headerCheckbox
                    Layout.preferredWidth: 30
                    checked: Utils.checkedCount > 0 && Utils.checkedCount === FilterProxyModel.rowCount()
                    tristate: Utils.checkedCount > 0 && Utils.checkedCount < FilterProxyModel.rowCount()
                    checkState: {
                        if (Utils.checkedCount === 0) return Qt.Unchecked
                        if (Utils.checkedCount === FilterProxyModel.rowCount()) return Qt.Checked
                        return Qt.PartiallyChecked
                    }
                    onClicked: {
                        if (Utils.checkedCount === FilterProxyModel.rowCount()) {
                            Utils.uncheckAll()
                        } else {
                            Utils.checkAll()
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
                    Layout.preferredWidth: 90
                }

                Label {
                    text: "Modified"
                    font.bold: true
                    Layout.preferredWidth: 140
                }

                Item {
                    Layout.preferredWidth: 40
                }
            }
        }
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

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

        DropIndicator {
            anchors.fill: parent
            z: 1000
            anchors.rightMargin: scrollView.ScrollBar.vertical.policy === ScrollBar.AlwaysOn ? 12 + 8 : 12
        }

        CustomScrollView {
            id: scrollView
            anchors.fill: parent

            ListView {
                id: listView
                width: scrollView.width - (scrollView.ScrollBar.vertical.policy === ScrollBar.AlwaysOn ? 12 + 8 : 12)
                height: contentHeight
                model: FilterProxyModel
                interactive: false
                spacing: 5
                header:

                Rectangle {
                    id: parentDirItem
                    visible: FileModel.canGoUp
                    width: parent.width - (scrollView.ScrollBar.vertical.policy === ScrollBar.AlwaysOn ? 12 + 8 : 12)
                    height: FileModel.canGoUp ? 50 : 0
                    color: "transparent"
                    radius: 4

                    property bool itemIsDir: true
                    property string itemPath: FileModel.canGoUp ? FileModel.getParentPath() : ""
                    property string itemName: ".."

                    ContextMenu.menu: ParentItemMenu {}

                    // Hover background
                    Rectangle {
                        anchors.fill: parent
                        color: Constants.alternateRowColor
                        opacity: parentHoverHandler.hovered && Utils.draggedItemPath === "" ? 1 : 0
                        radius: parent.radius
                        Behavior on opacity {
                            NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
                        }
                    }

                    // Drop target visual feedback
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        opacity: Utils.currentDropTarget === parentDirItem ? 1 : 0
                        color: Constants.listHeaderColor
                        border.width: 1
                        border.color: Material.accent

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.OutQuad
                            }
                        }
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
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32
                                source: "qrc:/icons/types/folder.svg"
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
                            Layout.preferredWidth: 90
                            opacity: 0.7
                        }

                        Label {
                            text: ""
                            Layout.preferredWidth: 140
                            opacity: 0.7
                        }

                        Item {
                            Layout.preferredWidth: 40
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


                delegate: Item {
                    id: delegateRoot
                    width: listView.width
                    height: 55
                    required property var model
                    required property int index

                    property string itemPath: model.path
                    property string itemName: model.name
                    property bool itemIsDir: model.isDir

                    ContextMenu.menu: ItemContextMenu {
                        id: contextMenu
                        itemPath: delegateRoot.itemPath
                        itemName: delegateRoot.itemName
                        itemIsDir: delegateRoot.itemIsDir
                        onDownloadCLicked: {
                            if (contextMenu.itemIsDir) {
                                Utils.openFolderDownloadDialog(contextMenu.itemPath, contextMenu.itemName + ".zip")
                            } else {
                                Utils.openFileDownloadDialog(contextMenu.itemPath, contextMenu.itemName)
                            }
                        }
                        shareEnabled: !delegateRoot.itemIsDir
                        onRenameClicked: fileListView.requestRename(contextMenu.itemPath, contextMenu.itemName)
                        onDeleteClicked: fileListView.requestDelete(contextMenu.itemPath, contextMenu.itemIsDir)
                        onShareClicked: ConnectionManager.generateShareLink(contextMenu.itemPath)
                        onPreviewClicked: fileListView.requestPreview(contextMenu.itemPath, contextMenu.itemName)
                    }

                    Rectangle {
                        id: delegateBackground
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: 50
                        color: "transparent"
                        radius: 4

                        // Hover background
                        Rectangle {
                            radius: parent.radius
                            anchors.fill: parent
                            color: Constants.alternateRowColor
                            opacity: hoverHandler.hovered && Utils.draggedItemPath === "" ? 1 : 0
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.OutQuad
                                }
                            }
                        }

                        // Drop target visual feedback
                        Rectangle {
                            radius: parent.radius
                            anchors.fill: parent
                            opacity: delegateRoot.itemIsDir && Utils.currentDropTarget === delegateRoot ? 1 : 0
                            color: Constants.listHeaderColor
                            border.width: 1
                            border.color: Material.accent

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.OutQuad
                                }
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 10

                            CheckBox {
                                Layout.preferredWidth: 30
                                checked: Utils.isItemChecked(delegateRoot.model.path)
                                onClicked: {
                                    Utils.toggleItemChecked(delegateRoot.model.path)
                                }
                                opacity: Utils.checkedCount !== 0 || hoverHandler.hovered ? 1 : 0
                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 200
                                        easing.type: Easing.OutQuad
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Image {
                                    Layout.preferredWidth: 32
                                    Layout.preferredHeight: 32
                                    fillMode: Image.PreserveAspectFit
                                    cache: false
                                    asynchronous: true
                                    source: {
                                        if (delegateRoot.model.isDir) {
                                            return "qrc:/icons/types/folder.svg"
                                        }
                                        if (delegateRoot.model.previewPath) {
                                            return delegateRoot.model.previewPath
                                        }
                                        return Utils.getFileIcon(delegateRoot.itemName)
                                    }

                                    onStatusChanged: {
                                        if (status === Image.Error && !delegateRoot.model.isDir) {
                                            source = Utils.getFileIcon(delegateRoot.itemName)
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
                                text: delegateRoot.model.isDir ? "-" : Utils.formatSize(delegateRoot.model.size)
                                Layout.preferredWidth: 90
                                opacity: 0.7
                            }

                            Label {
                                text: Utils.formatDate(delegateRoot.model.modified)
                                Layout.preferredWidth: 140
                                opacity: 0.7
                            }

                            RowLayout {
                                Layout.preferredWidth: 40
                                spacing: 2

                                CustomButton {
                                    icon.source: "qrc:/icons/menu.svg"
                                    icon.width: 16
                                    icon.height: 16
                                    flat: true
                                    onClicked: contextMenu.popup()
                                    Layout.alignment: Qt.AlignRight
                                    opacity: (hoverHandler.hovered && Utils.draggedItemPath === "") ? (hovered ? 1 : 0.5) : 0
                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: 200
                                            easing.type: Easing.OutQuad
                                        }
                                    }
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
                            enabled: !Utils.anyDialogOpen

                            onActiveChanged: {
                                if (active) {
                                    let dragText = Utils.startDrag(delegateRoot.itemPath, delegateRoot.itemName)
                                    fileListView.setDragIndicatorText(dragText)
                                    fileListView.setDragIndicatorVisible(true)
                                } else {
                                    fileListView.setDragIndicatorVisible(false)

                                    if (Utils.currentDropTarget) {
                                        let targetPath = Utils.currentDropTarget.itemPath

                                        if (Utils.currentDropTarget.itemIsDir) {
                                            if (Utils.isDraggingMultiple) {
                                                // Move all selected items
                                                let itemsToMove = Utils.draggedItems.filter(path => {
                                                    let sourceParent = path.substring(0, path.lastIndexOf('/'))
                                                    return path !== targetPath && sourceParent !== targetPath
                                                })

                                                if (itemsToMove.length > 0) {
                                                    ConnectionManager.moveMultiple(itemsToMove, targetPath)
                                                    Utils.uncheckAll()
                                                }
                                            } else {
                                                // Single item move (existing logic)
                                                let sourceParent = Utils.draggedItemPath.substring(0, Utils.draggedItemPath.lastIndexOf('/'))
                                                if (sourceParent !== targetPath && Utils.draggedItemPath !== targetPath) {
                                                    ConnectionManager.moveItem(Utils.draggedItemPath, targetPath)
                                                }
                                            }
                                        }
                                    }

                                    Utils.endDrag()
                                }
                            }

                            onCentroidChanged: {
                                if (active) {
                                    let globalPos = delegateBackground.mapToItem(null, centroid.position.x, centroid.position.y)
                                    fileListView.setDragIndicatorX(globalPos.x + 10)
                                    fileListView.setDragIndicatorY(globalPos.y + 10)

                                    let listPos = delegateBackground.mapToItem(listView, centroid.position.x, centroid.position.y)

                                    Utils.currentDropTarget = null

                                    // Check parent directory item first (if it exists as header)
                                    if (FileModel.canGoUp && listView.headerItem) {
                                        let parentItem = listView.headerItem
                                        let parentPos = parentItem.mapFromItem(listView, listPos.x, listPos.y)
                                        if (parentPos.x >= 0 && parentPos.x <= parentItem.width &&
                                            parentPos.y >= 0 && parentPos.y <= parentItem.height) {

                                            let validTarget = true
                                            if (Utils.isDraggingMultiple) {
                                                // Check if any item can be moved to parent
                                                validTarget = Utils.draggedItems.some(path => {
                                                    let sourceParent = path.substring(0, path.lastIndexOf('/'))
                                                    return sourceParent !== FileModel.getParentPath()
                                                })
                                            } else {
                                                let sourceParent = Utils.draggedItemPath.substring(0, Utils.draggedItemPath.lastIndexOf('/'))
                                                validTarget = sourceParent !== FileModel.getParentPath()
                                            }

                                            if (validTarget) {
                                                Utils.currentDropTarget = parentItem
                                            }
                                            return
                                        }
                                    }

                                    // Check list items
                                    for (let i = 0; i < listView.count; i++) {
                                        let item = listView.itemAtIndex(i)
                                        if (item) {
                                            let itemPos = item.mapFromItem(listView, listPos.x, listPos.y)
                                            if (itemPos.x >= 0 && itemPos.x <= item.width &&
                                                itemPos.y >= 0 && itemPos.y <= item.height) {

                                                // Only folders are valid drop targets
                                                if (item.itemIsDir) {
                                                    let validTarget = true
                                                    if (Utils.isDraggingMultiple) {
                                                        // Don't allow if dragging the target itself or if all items already in target
                                                        validTarget = !Utils.draggedItems.includes(item.itemPath) &&
                                                                     Utils.draggedItems.some(path => {
                                                            let sourceParent = path.substring(0, path.lastIndexOf('/'))
                                                            return sourceParent !== item.itemPath
                                                        })
                                                    } else {
                                                        let sourceParent = Utils.draggedItemPath.substring(0, Utils.draggedItemPath.lastIndexOf('/'))
                                                        validTarget = item.itemPath !== Utils.draggedItemPath &&
                                                                    sourceParent !== item.itemPath
                                                    }

                                                    if (validTarget) {
                                                        Utils.currentDropTarget = item
                                                    }
                                                }
                                                break
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        TapHandler {
                            acceptedButtons: Qt.LeftButton
                            onTapped: Utils.toggleItemChecked(delegateRoot.model.path)
                            onDoubleTapped: {
                                if (delegateRoot.model.isDir) {
                                    ConnectionManager.listDirectory(delegateRoot.model.path, UserSettings.foldersFirst)
                                } else if (Utils.isImageFile(delegateRoot.itemName) || Utils.isEditableTextFile(delegateRoot.itemName)) {
                                    fileListView.requestPreview(delegateRoot.itemPath, delegateRoot.itemName)
                                }
                            }
                        }
                    }

                    Separator {
                        anchors.top: delegateBackground.bottom
                        visible: delegateRoot.index !== listView.count - 1
                    }
                }
            }
        }
    }
}
