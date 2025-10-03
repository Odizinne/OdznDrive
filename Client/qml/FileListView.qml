import QtQuick
import QtQuick.Controls.Material
import QtQuick.Layouts
import Odizinne.OdznDriveClient

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
        opacity: 0.9
        z: 1000
        parent: Overlay.overlay

        Label {
            id: dragLabel
            anchors.centerIn: parent
            color: Material.background
            font.bold: true
        }
    }

    property string draggedItemPath: ""
    property string draggedItemName: ""
    property var currentDropTarget: null

    ScrollView {
        id: scrollView
        anchors.fill: parent
        clip: true

        ListView {
            id: listView
            width: scrollView.width
            model: FileModel
            interactive: false

            headerPositioning: ListView.OverlayHeader

            header: Rectangle {
                width: listView.width
                height: 40
                color: Constants.listHeaderColor
                z: 2

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

            delegate: Item {
                id: delegateRoot
                width: listView.width
                height: 50

                property string itemPath: model.path
                property string itemName: model.name
                property bool itemIsDir: model.isDir

                Rectangle {
                    id: delegateBackground
                    anchors.fill: parent
                    color: (root.currentDropTarget === delegateRoot && model.isDir && root.draggedItemPath !== model.path) ?
                           Constants.listHeaderColor :
                           (index % 2 === 0 ? Constants.surfaceColor : Constants.alternateRowColor)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        Label {
                            text: (model.isDir ? "📁 " : "📄 ") + model.name
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        Label {
                            text: model.isDir ? "-" : formatSize(model.size)
                            Layout.preferredWidth: 100
                            opacity: 0.7
                        }

                        Label {
                            text: formatDate(model.modified)
                            Layout.preferredWidth: 180
                            opacity: 0.7
                        }

                        RowLayout {
                            Layout.preferredWidth: 80
                            spacing: 2

                            ToolButton {
                                text: "↓"
                                visible: !model.isDir
                                onClicked: {
                                    root.Window.window.showDownloadDialog(model.path)
                                }
                                ToolTip.visible: hovered
                                ToolTip.text: "Download"
                            }

                            ToolButton {
                                text: "✕"
                                onClicked: {
                                    root.Window.window.showDeleteConfirm(model.path, model.isDir)
                                }
                                ToolTip.visible: hovered
                                ToolTip.text: "Delete"
                            }
                        }
                    }

                    DragHandler {
                        id: dragHandler
                        target: null
                        dragThreshold: 15

                        onActiveChanged: {
                            if (active) {
                                root.draggedItemPath = model.path
                                root.draggedItemName = model.name
                                dragLabel.text = "Move " + model.name
                                dragIndicator.visible = true
                            } else {
                                dragIndicator.visible = false

                                if (root.currentDropTarget &&
                                    root.currentDropTarget.itemIsDir &&
                                    root.currentDropTarget.itemPath !== root.draggedItemPath) {
                                    ConnectionManager.moveItem(root.draggedItemPath, root.currentDropTarget.itemPath)
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
                            if (model.isDir) {
                                ConnectionManager.listDirectory(model.path)
                            }
                        }
                    }
                }
            }

            Label {
                anchors.centerIn: parent
                text: ConnectionManager.authenticated ?
                      (FileModel.count === 0 ? "Empty folder" : "") :
                      "Not connected"
                visible: FileModel.count === 0
                opacity: 0.5
                font.pixelSize: 16
            }
        }
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
