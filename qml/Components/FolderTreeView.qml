pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Material
import QtQuick.Controls.Material.impl
import QtQuick.Controls.impl
import QtQuick.Layouts
import Odizinne.OdznDrive

Item {
    Rectangle {
        anchors.fill: parent
        color: Constants.surfaceColor
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

            onPositionChanged: (mouse) => {
                if (Utils.draggedItemPath === "") {
                    return
                }

                let listPos = mapToItem(treeListView, mouse.x, mouse.y)

                for (let i = 0; i < treeListView.count; i++) {
                    let item = treeListView.itemAtIndex(i)
                    if (item) {
                        let itemPos = item.mapFromItem(treeListView, listPos.x, listPos.y)
                        if (itemPos.x >= 0 && itemPos.x <= item.width &&
                            itemPos.y >= 0 && itemPos.y <= item.height) {

                            let itemPath = getItemPath(item)
                            if (itemPath && itemPath !== Utils.draggedItemPath) {
                                Utils.currentDropTarget = item
                            }
                            return
                        }
                    }
                }

                if (Utils.currentDropTarget && isTreeViewChild(Utils.currentDropTarget)) {
                    Utils.currentDropTarget = null
                }
            }

            onExited: {
                if (Utils.currentDropTarget && isTreeViewChild(Utils.currentDropTarget)) {
                    Utils.currentDropTarget = null
                }
            }
        }

        CustomScrollView {
            id: scroll
            anchors.fill: parent
            anchors.margins: 8

            ListView {
                id: treeListView
                width: scroll.width
                height: contentHeight
                model: TreeModel
                interactive: false
                spacing: 2

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
    }
}
