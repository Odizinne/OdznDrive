pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Material
import QtQuick.Controls.Material.impl
import QtQuick.Controls.impl
import QtQuick.Layouts
import Odizinne.OdznDrive

Item {
    id: treeView
    signal showUserManagmentDialog()
    signal showAdvancedSettingsDialog()
    signal requestMultiDeleteConfirmDialog()

    Rectangle {
        anchors.fill: parent
        color: Constants.altSurfaceColor
        radius: 4
        layer.enabled: true
        layer.effect: RoundedElevationEffect {
            elevation: 6
            roundedScale: 4
        }

        MouseArea {
            id: treeDropArea
            anchors.fill: parent
            propagateComposedEvents: true
            acceptedButtons: Qt.NoButton
            hoverEnabled: true
            preventStealing: false

            function getItemPath(item) {
                return item && "itemPath" in item ? item.itemPath : ""
            }

            function isTreeViewChild(item) {
                if (!item) return false
                let parent = item.parent
                while (parent) {
                    if (parent === treeListView) return true
                    parent = parent.parent
                }
                return false
            }

            function isValidDropTarget(item, targetPath) {
                if (!item || targetPath === null || targetPath === undefined) {
                    return false
                }

                if (Utils.isDraggingMultiple) {
                    if (Utils.draggedItems.includes(targetPath)) {
                        return false
                    }
                    let result = Utils.draggedItems.some(path => {
                        let sourceParent = path.substring(0, path.lastIndexOf('/'))
                        return path !== targetPath && sourceParent !== targetPath
                    })
                    return result
                } else {
                    if (targetPath === Utils.draggedItemPath) {
                        return false
                    }
                    let sourceParent = Utils.draggedItemPath.substring(0, Utils.draggedItemPath.lastIndexOf('/'))
                    let result = sourceParent !== targetPath
                    return result
                }
            }

            onPositionChanged: (mouse) => {
                if (Utils.draggedItemPath === "") {
                    return
                }

                let listPos = mapToItem(treeListView, mouse.x, mouse.y)
                let foundTarget = null

                for (let i = 0; i < treeListView.count; i++) {
                    let item = treeListView.itemAtIndex(i)
                    if (item) {
                        let itemPos = item.mapFromItem(treeListView, listPos.x, listPos.y)
                        if (itemPos.x >= 0 && itemPos.x <= item.width &&
                            itemPos.y >= 0 && itemPos.y <= item.height) {

                            let itemPath = getItemPath(item)
                            if (isValidDropTarget(item, itemPath)) {
                                foundTarget = item
                            }
                            break
                        }
                    }
                }

                Utils.currentDropTarget = foundTarget
            }

            onExited: {
                if (Utils.currentDropTarget && isTreeViewChild(Utils.currentDropTarget)) {
                    Utils.currentDropTarget = null
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8

            Rectangle {
                color: Constants.treeDelegateHoverColor
                Layout.preferredHeight: 45
                Layout.fillWidth: true
                topLeftRadius: 4
                topRightRadius: 4
                bottomLeftRadius: menu.opened ? 0 : 4
                bottomRightRadius: menu.opened ? 0 : 4

                layer.enabled: true
                layer.effect: RoundedElevationEffect {
                    elevation: 6
                    roundedScale: 0
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 6

                    CustomButton {
                        id: menuButton
                        onClicked: menu.visible ? menu.close() : menu.open()
                        icon.source: "qrc:/icons/cog.svg"
                        icon.width: 16
                        icon.height: 16
                    }

                    CustomButton {
                        visible: opacity !== 0
                        opacity: Utils.checkedCount > 0 ? 1 : 0
                        icon.source: "qrc:/icons/download.svg"
                        icon.width: 16
                        icon.height: 16
                        enabled: ConnectionManager.authenticated
                        onClicked: {
                            let items = Utils.getCheckedItems()

                            if (items.length === 1) {
                                if (items[0].isDir) {
                                    Utils.openFolderDownloadDialog(items[0].path, items[0].name + ".zip")
                                } else {
                                    Utils.openFileDownloadDialog(items[0].path, items[0].name)
                                }
                            } else {
                                Utils.openMultiDownloadDialog(Utils.getCheckedPaths())
                            }
                        }
                        ToolTip.visible: hovered
                        ToolTip.text: Utils.checkedCount === 1 ? "Download" : "Download as zip"

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.OutQuad
                            }
                        }
                    }

                    CustomButton {
                        visible: opacity !== 0
                        opacity: Utils.checkedCount > 0 ? 1 : 0
                        icon.source: "qrc:/icons/delete.svg"
                        icon.width: 16
                        icon.height: 16
                        enabled: ConnectionManager.authenticated
                        onClicked: Utils.requestMultiDeleteConfirmDialog()
                        ToolTip.visible: hovered
                        ToolTip.text: "Delete selected"

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.OutQuad
                            }
                        }
                    }

                    Rectangle {
                        visible: opacity !== 0
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 24
                        color: Material.foreground
                        opacity: Utils.checkedCount > 0 ? 0.3 : 0
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.OutQuad
                            }
                        }
                    }

                    Label {
                        visible: opacity !== 0
                        Layout.leftMargin: 8
                        opacity: Utils.checkedCount > 0 ? 0.7 : 0
                        text: Utils.checkedCount + (Utils.checkedCount === 1 ? " item" : " items")

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.OutQuad
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }
            }

            MainMenu {
                id: menu
                Layout.fillWidth: true
                Layout.preferredHeight: menuHeight
                Layout.topMargin: -6
            }

            CustomScrollView {
                opacity: !menu.visible ? 1 : 0
                id: scroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                Behavior on opacity {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutQuad
                    }
                }

                ListView {
                    id: treeListView
                    width: scroll.width
                    height: contentHeight
                    model: TreeModel
                    interactive: false
                    spacing: 2

                    add: Transition {
                        NumberAnimation {
                            property: "opacity"
                            from: 0
                            to: 1
                            duration: 200
                        }
                    }

                    displaced: Transition {
                        NumberAnimation {
                            properties: "x,y"
                            duration: 200
                        }
                    }

                    delegate: Item {
                        id: treeDelegate
                        width: treeListView.width
                        height: 35

                        required property string name
                        required property string path
                        required property bool isExpanded
                        required property bool hasChildren
                        required property int depth
                        required property int index

                        property bool itemIsDir: true
                        property string itemPath: treeDelegate.path
                        property string itemName: treeDelegate.name
                        property bool draggingOn: Utils.currentDropTarget === treeDelegate && Utils.draggedItemPath !== "" && Utils.draggedItemPath !== treeDelegate.path

                        SequentialAnimation {
                            id: removeAnimation
                            PropertyAction { target: treeDelegate; property: "ListView.delayRemove"; value: true }
                            NumberAnimation {
                                target: treeDelegate;
                                property: "opacity";
                                to: 0;
                                duration: 200;
                                easing.type: Easing.OutQuad
                            }
                            PropertyAction { target: treeDelegate; property: "ListView.delayRemove"; value: false }
                        }

                        ListView.onRemove: removeAnimation.start()

                        Rectangle {
                            id: delegateBackground
                            anchors.fill: parent
                            color: "transparent"
                            radius: 4

                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                opacity: treeDelegate.draggingOn ? 1 : 0
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

                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                opacity: treeHoverHandler.hovered && !treeDelegate.draggingOn ? 1 : 0
                                color: Constants.treeDelegateHoverColor

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 200
                                        easing.type: Easing.OutQuad
                                    }
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10 + (treeDelegate.depth * 20)
                                anchors.rightMargin: 10
                                spacing: 5

                                Item {
                                    Layout.preferredWidth: 20
                                    Layout.preferredHeight: 20
                                    visible: treeDelegate.hasChildren

                                    MouseArea {
                                        id: expandCollapseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: TreeModel.toggleExpanded(treeDelegate.path)
                                    }

                                    IconImage {
                                        anchors.fill: parent
                                        source: "qrc:/icons/right.svg"
                                        sourceSize.width: 12
                                        sourceSize.height: 12
                                        color: Material.foreground
                                        opacity: expandCollapseArea.containsMouse ? 1 : 0.5
                                        rotation: treeDelegate.isExpanded ? 90 : 0

                                        Behavior on opacity {
                                            NumberAnimation {
                                                duration: 200
                                                easing.type: Easing.OutQuad
                                            }
                                        }

                                        Behavior on rotation {
                                            NumberAnimation {
                                                duration: 200
                                                easing.type: Easing.OutQuad
                                            }
                                        }
                                    }
                                }

                                Item {
                                    Layout.preferredWidth: 20
                                    visible: !treeDelegate.hasChildren
                                }

                                Image {
                                    Layout.preferredWidth: 20
                                    Layout.preferredHeight: 20
                                    source: "qrc:/icons/types/folder.svg"
                                    fillMode: Image.PreserveAspectFit
                                }

                                Label {
                                    text: treeDelegate.name
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    font.bold: FileModel.currentPath === treeDelegate.path
                                }
                            }

                            HoverHandler {
                                id: treeHoverHandler
                                enabled: Utils.draggedItemPath === ""
                            }

                            TapHandler {
                                onTapped: {
                                    ConnectionManager.listDirectory(treeDelegate.path, UserSettings.foldersFirst)
                                }
                            }
                        }
                    }
                }
            }

            TextField {
                Layout.fillWidth: true
                Layout.preferredHeight: 35
                placeholderText: "Filter..."
                onTextChanged: FilterProxyModel.filterText = text
                Layout.leftMargin: 10
                Layout.rightMargin: 10
                Layout.bottomMargin: 6
            }

            ColumnLayout {
                spacing: 6
                Layout.leftMargin: 10
                Layout.rightMargin: 10

                CustomProgressBar {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 8
                    Material.accent: Utils.storagePercentage < 0.5 ? Material.Green : Utils.storagePercentage < 0.85 ? Material.Orange : Material.Red
                    value: Utils.storagePercentage
                    Material.background: Constants.backgroundColor
                }

                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: 4

                    Label {
                        text: Utils.storageOccupied
                        font.pixelSize: 12
                        font.bold: true
                        opacity: 0.7
                    }

                    Label {
                        text: "/"
                        font.pixelSize: 12
                        opacity: 0.7
                    }

                    Label {
                        text: Utils.storageTotal
                        font.pixelSize: 12
                        opacity: 0.7
                    }
                }
            }
        }
    }
}
