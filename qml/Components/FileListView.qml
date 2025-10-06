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
    signal setDragIndicatorX(int x)
    signal setDragIndicatorY(int y)
    signal setDragIndicatorVisible(bool visible)
    signal setDragIndicatorText(string text)

    function setScrollViewMenu(menu) {
        scrollView.ContextMenu.menu = menu
    }

    Item {
        Layout.preferredWidth: listView.width
        Layout.preferredHeight: 55 + (FileModel.canGoUp ? 60 : 0)
        z: 2

        Rectangle {
            id: columnHeader
            width: parent.width
            height: 55
            clip: true
            color: Constants.backgroundColor

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
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
            color: "transparent"

            Rectangle {
                anchors.fill: parent
                color: parentHoverHandler.hovered ? Constants.alternateRowColor : "transparent"
                opacity: parentHoverHandler.hovered ? 1 : 0
                radius: 4
                Behavior on opacity {
                    NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
                }
            }


            property bool itemIsDir: true
            property string itemPath: FileModel.canGoUp ? FileModel.getParentPath() : ""
            property string itemName: ".."

            ContextMenu.menu: CustomMenu {
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

        Separator {
            anchors.top: parentDirItem.bottom
            visible: parentDirItem.visible && listView.count > 0
        }
    }

    CustomScrollView {
        id: scrollView
        Layout.fillWidth: true
        Layout.fillHeight: true

        ListView {
            id: listView
            width: scrollView.width
            height: contentHeight
            model: FilterProxyModel
            interactive: false

            spacing: 5
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

                    onRenameClicked: fileListView.requestRename(contextMenu.itemPath, contextMenu.itemName)
                    onDeleteClicked: fileListView.requestDelete(contextMenu.itemPath, contextMenu.itemIsDir)
                }

                Rectangle {
                    id: delegateBackground
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 50
                    color: "transparent"

                    Rectangle {
                        anchors.fill: parent
                        color: {
                            if (Utils.currentDropTarget === delegateRoot && delegateRoot.model.isDir && Utils.draggedItemPath !== delegateRoot.model.path) {
                                return Constants.listHeaderColor
                            }
                            return hoverHandler.hovered ? Constants.alternateRowColor : "transparent"
                        }
                        opacity: hoverHandler.hovered ? 1 : 0
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
                            text: delegateRoot.model.isDir ? "-" : Utils.formatSize(delegateRoot.model.size)
                            Layout.preferredWidth: 100
                            opacity: 0.7
                        }

                        Label {
                            text: Utils.formatDate(delegateRoot.model.modified)
                            Layout.preferredWidth: 180
                            opacity: 0.7
                        }

                        RowLayout {
                            Layout.preferredWidth: 80
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
                                Utils.draggedItemPath = delegateRoot.model.path
                                Utils.draggedItemName = delegateRoot.model.name
                                fileListView.setDragIndicatorText("Move " + delegateRoot.model.name)
                                fileListView.setDragIndicatorVisible(true)
                            } else {
                                fileListView.setDragIndicatorVisible(false)

                                if (Utils.currentDropTarget) {
                                    let targetPath = Utils.currentDropTarget.itemPath

                                    if (Utils.currentDropTarget.itemIsDir &&
                                        targetPath !== Utils.draggedItemPath) {
                                        ConnectionManager.moveItem(Utils.draggedItemPath, targetPath)
                                    }
                                }

                                Utils.draggedItemPath = ""
                                Utils.draggedItemName = ""
                                Utils.currentDropTarget = null
                            }
                        }

                        onCentroidChanged: {
                            if (active) {
                                let globalPos = delegateBackground.mapToItem(null, centroid.position.x, centroid.position.y)

                                fileListView.setDragIndicatorX(globalPos.x + 10)
                                fileListView.setDragIndicatorY(globalPos.y + 10)

                                let listPos = delegateBackground.mapToItem(listView, centroid.position.x, centroid.position.y)

                                Utils.currentDropTarget = null

                                if (FileModel.canGoUp) {
                                    let headerItem = listView.headerItem
                                    if (headerItem) {
                                        let parentDirItem = headerItem.children[1]
                                        if (parentDirItem) {
                                            let parentPos = parentDirItem.mapFromItem(listView, listPos.x, listPos.y)
                                            if (parentPos.x >= 0 && parentPos.x <= parentDirItem.width &&
                                                parentPos.y >= 0 && parentPos.y <= parentDirItem.height) {
                                                Utils.currentDropTarget = parentDirItem
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
                                            Utils.currentDropTarget = item
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

