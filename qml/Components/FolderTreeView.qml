import QtQuick
import QtQuick.Controls.Material
import QtQuick.Controls.impl
import QtQuick.Layouts
import Odizinne.OdznDrive

CustomScrollView {
    id: root

    Component.onCompleted: {
        console.log("TreeView created, model row count:", TreeModel.rowCount())
    }

    Connections {
        target: TreeModel
        function onRowsInserted() {
            console.log("Rows inserted, new count:", TreeModel.rowCount())
        }
        function onModelReset() {
            console.log("Model reset, new count:", TreeModel.rowCount())
        }
    }

    ListView {
        id: treeListView
        width: root.width
        height: contentHeight
        model: TreeModel
        interactive: false

        header: Label {
            text: "Folders (" + TreeModel.rowCount() + ")"
            font.bold: true
            padding: 10
        }

        delegate: Item {
            id: treeDelegate
            width: root.width
            height: 35

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.color: "red"
                border.width: 1
            }

            required property string name
            required property string path
            required property bool isExpanded
            required property bool hasChildren
            required property int depth
            required property int index

            Component.onCompleted: {
                console.log("Delegate created:", index, name, "path:", path, "depth:", depth, "hasChildren:", hasChildren)
            }

            Rectangle {
                anchors.fill: parent
                color: treeHoverHandler.hovered ? Constants.alternateRowColor : "transparent"
                radius: 4

                Behavior on color {
                    ColorAnimation { duration: 150 }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10 + (treeDelegate.depth * 20)
                    spacing: 5

                    Item {
                        Layout.preferredHeight: 32
                        Layout.preferredWidth: 32

                        IconImage {
                            sourceSize.height: 12
                            sourceSize.width: 12
                            source: "qrc:/icons/right.svg"
                            rotation: treeDelegate.isExpanded ? 90 : 0
                            color: Material.foreground
                            anchors.centerIn: parent
                            opacity: area.containsMouse ? 1 : 0.5

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

                        MouseArea {
                            id: area
                            anchors.fill: parent
                            onClicked: TreeModel.toggleExpanded(treeDelegate.path)
                            hoverEnabled: true
                        }
                    }

                    Item {
                        Layout.preferredWidth: 20
                        visible: !treeDelegate.hasChildren
                    }

                    Image {
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                        sourceSize.width: 20
                        sourceSize.height: 20
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
                }

                TapHandler {
                    onTapped: {
                        console.log("Navigating to:", treeDelegate.path)
                        ConnectionManager.listDirectory(treeDelegate.path, UserSettings.foldersFirst)
                    }
                }
            }
        }
    }
}
