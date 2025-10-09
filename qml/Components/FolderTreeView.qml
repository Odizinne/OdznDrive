pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Material
import QtQuick.Controls.Material.impl
import QtQuick.Controls.impl
import QtQuick.Layouts
import Odizinne.OdznDrive

Rectangle {
    id: root2
    color: Constants.surfaceColor
    radius: 4
    layer.enabled: true
    layer.effect: RoundedElevationEffect {
        elevation: 6
        roundedScale: 4
    }

    function checkTreeViewDropTarget() {
        // Get the global mouse position from the drag indicator
        // We need to check if the mouse is over the tree view
        let mousePos = root.mapFromGlobal(Qt.point(0, 0)) // This won't work directly

        // Instead, we'll check each visible tree item
        // This will be called frequently during drag

        // Note: This is a simplified approach
        // In practice, you'd need to track the actual mouse position
        // which is already being done in FileListView and FileTileView
    }

    // Monitor drag position globally to detect tree view drops
    Connections {
        target: Utils

        function onDraggedItemPathChanged() {
            if (Utils.draggedItemPath !== "") {
                // Start monitoring
                dragMonitor.start()
            } else {
                // Stop monitoring
                dragMonitor.stop()
            }
        }
    }

    Timer {
        id: dragMonitor
        interval: 16 // ~60fps
        repeat: true
        running: false

        onTriggered: {
            if (Utils.draggedItemPath === "") {
                stop()
                return
            }

            root2.checkTreeViewDropTarget()
        }
    }

    MouseArea {
        id: treeDropArea
        anchors.fill: parent
        propagateComposedEvents: true
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
        preventStealing: false

        onPositionChanged: (mouse) => {
            if (Utils.draggedItemPath === "") {
                return
            }

            // Map position to tree list view
            let listPos = mapToItem(treeListView, mouse.x, mouse.y)

            // Check if we're over a tree item
            for (let i = 0; i < treeListView.count; i++) {
                let item = treeListView.itemAtIndex(i)
                if (item) {
                    let itemPos = item.mapFromItem(treeListView, listPos.x, listPos.y)
                    if (itemPos.x >= 0 && itemPos.x <= item.width &&
                        itemPos.y >= 0 && itemPos.y <= item.height) {
                        // Found the tree item under mouse
                        // Only set as drop target if it's a different folder
                        if (item.itemPath !== Utils.draggedItemPath) {
                            Utils.currentDropTarget = item
                        }
                        return
                    }
                }
            }

            // Not over any tree item, clear if current target is in tree
            if (Utils.currentDropTarget && Utils.currentDropTarget.parent === treeListView) {
                Utils.currentDropTarget = null
            }
        }

        onExited: {
            // Clear drop target if it's in the tree view
            if (Utils.currentDropTarget && Utils.currentDropTarget.parent === treeListView) {
                Utils.currentDropTarget = null
            }
        }
    }

    CustomScrollView {
        id: root
        anchors.fill: parent
        anchors.margins: 8

        ListView {
            id: treeListView
            width: root.width
            height: contentHeight
            model: TreeModel
            interactive: false
            spacing: 2

            //header: Rectangle {
            //    width: treeListView.width
            //    height: 40
            //    color: Constants.listHeaderColor
//
            //    Label {
            //        anchors.fill: parent
            //        anchors.leftMargin: 10
            //        text: "Folders"
            //        font.bold: true
            //        verticalAlignment: Text.AlignVCenter
            //    }
            //}

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

                // Expose properties for drop targeting
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
                        color: Constants.alternateRowColor

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
