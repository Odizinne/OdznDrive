pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Material
import QtQuick.Layouts
import Odizinne.OdznDrive
import Qt5Compat.GraphicalEffects

Item {
    id: root
    signal requestRename(string path, string name)
    signal requestDelete(string path, bool isDir)
    signal setDragIndicatorX(int x)
    signal setDragIndicatorY(int y)
    signal setDragIndicatorVisible(bool visible)
    signal setDragIndicatorText(string text)

    DropIndicator {
        id: dragIndicator
        anchors.fill: parent
        anchors.rightMargin: tileScrollView.ScrollBar.vertical.policy === ScrollBar.AlwaysOn ? 20 : 12
        z: 1000
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

    CustomScrollView {
        id: tileScrollView
        anchors.fill: parent
        contentWidth: width
        contentHeight: tileContainer.implicitHeight

        Connections {
            target: FileModel

            function onDataChanged(topLeft, bottomRight, roles) {
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
            id: tileContainer
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
                    rightMargin: tileScrollView.ScrollBar.vertical.policy === ScrollBar.AlwaysOn ? 20 : 12
                }
                height: Math.ceil(count / Math.floor(width / cellWidth)) * cellHeight
                interactive: false

                property int minCellWidth: 210
                property int columns: Math.max(1, Math.floor(width / minCellWidth))
                property real cellSize: Math.floor(width / columns)
                cellWidth: cellSize
                cellHeight: cellSize - 30

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

                            let sizeText = tileDelegateRoot.itemIsDir ? "-" : Utils.formatSize(tileDelegateRoot.model.size)
                            let dateText = Utils.formatDate(tileDelegateRoot.model.modified)

                            return "Size: " + sizeText + "\nModified: " + dateText
                        }
                    }

                    Rectangle {
                        id: tileRect
                        anchors.fill: parent
                        anchors.margins: 5
                        radius: 4
                        color: "transparent"
                        border.width: 1
                        border.color: {
                            if (Utils.currentDropTarget === tileDelegateRoot && tileDelegateRoot.itemIsDir && Utils.draggedItemPath !== tileDelegateRoot.itemPath) {
                                return Material.accent
                            }
                            if (!tileDelegateRoot.isParentItem && Utils.isItemChecked(tileDelegateRoot.itemPath)) {
                                return Material.accent
                            }
                            return Constants.borderColor
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: {
                                if (tileHoverHandler.hovered) {
                                    return Constants.alternateRowColor
                                }
                                return "transparent"
                            }
                            anchors.margins: 1
                            opacity: tileHoverHandler.hovered ? 1 : 0
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.OutQuad
                                }
                            }
                        }

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
                                    checked: Utils.isItemChecked(tileDelegateRoot.itemPath)
                                    onClicked: {
                                        Utils.toggleItemChecked(tileDelegateRoot.itemPath)
                                    }
                                    opacity: Utils.checkedCount !== 0 || tileHoverHandler.hovered ? 1 : 0
                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: 200
                                            easing.type: Easing.OutQuad
                                        }
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
                                            return "qrc:/icons/types/folder.svg"
                                        }
                                        return Utils.getFileIcon(tileDelegateRoot.itemName)
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
                                Label {
                                    anchors.fill: parent
                                    anchors.leftMargin: 32
                                    anchors.rightMargin: 32
                                    anchors.bottomMargin: 5
                                    text: tileDelegateRoot.itemName
                                    elide: Text.ElideMiddle
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    font.bold: tileDelegateRoot.isParentItem ? true : Utils.isItemChecked(tileDelegateRoot.itemPath)
                                    font.pixelSize: 13
                                    wrapMode: Text.NoWrap
                                    opacity: tileDelegateRoot.isParentItem ? 0.7 : 1.0
                                }

                                CustomButton {
                                    icon.source: "qrc:/icons/menu.svg"
                                    icon.width: 16
                                    icon.height: 16
                                    anchors.right: parent.right
                                    anchors.rightMargin: 5
                                    anchors.verticalCenter: parent.verticalCenter
                                    flat: true
                                    onClicked: tileContextMenu.popup()
                                    opacity: (tileHoverHandler.hovered && Utils.draggedItemPath === "") ? (hovered ? 1 : 0.5) : 0
                                    Material.roundedScale: Material.ExtraSmallScale
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
                                    let dragText = Utils.startDrag(tileDelegateRoot.itemPath, tileDelegateRoot.itemName)
                                    root.setDragIndicatorText(dragText)
                                    root.setDragIndicatorVisible(true)
                                } else {
                                    root.setDragIndicatorVisible(false)

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
                                    let globalPos = tileRect.mapToItem(null, centroid.position.x, centroid.position.y)
                                    root.setDragIndicatorX(globalPos.x + 10)
                                    root.setDragIndicatorY(globalPos.y + 10)

                                    let gridPos = tileRect.mapToItem(tileGrid, centroid.position.x, centroid.position.y)

                                    Utils.currentDropTarget = null

                                    for (let i = 0; i < tileGrid.count; i++) {
                                        let item = tileGrid.itemAtIndex(i)
                                        if (item) {
                                            let itemPos = item.mapFromItem(tileGrid, gridPos.x, gridPos.y)
                                            if (itemPos.x >= 0 && itemPos.x <= item.width &&
                                                itemPos.y >= 0 && itemPos.y <= item.height) {

                                                if (item.itemIsDir) {
                                                    let validTarget = true
                                                    if (Utils.isDraggingMultiple) {
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
                            onTapped: {
                                if (!tileDelegateRoot.isParentItem) {
                                    Utils.toggleItemChecked(tileDelegateRoot.itemPath)
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

                        ItemContextMenu {
                            id: tileContextMenu
                            itemPath: tileDelegateRoot.itemPath
                            itemName: tileDelegateRoot.itemName
                            itemIsDir: tileDelegateRoot.itemIsDir

                            onDownloadCLicked: {
                                if (tileContextMenu.itemIsDir) {
                                    Utils.openFolderDownloadDialog(tileContextMenu.itemPath, tileContextMenu.itemName + ".zip")
                                } else {
                                    Utils.openFileDownloadDialog(tileContextMenu.itemPath, tileContextMenu.itemName)
                                }
                            }
                            shareEnabled: !tileDelegateRoot.itemIsDir
                            onRenameClicked: root.requestRename(tileContextMenu.itemPath, tileContextMenu.itemName)
                            onDeleteClicked: root.requestDelete(tileContextMenu.itemPath, tileContextMenu.itemIsDir)
                            onShareClicked: ConnectionManager.generateShareLink(tileContextMenu.itemPath)
                        }

                        ParentItemMenu {
                            id: parentItemMenu
                        }
                    }
                }
            }
        }
    }
}
