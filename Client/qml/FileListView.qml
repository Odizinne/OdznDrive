import QtQuick
import QtQuick.Controls.Material
import QtQuick.Layouts
import Odizinne.OdznDriveClient

Rectangle {
    id: root
    color: Constants.backgroundColor

    ListView {
        id: listView
        anchors.fill: parent
        model: FileModel
        clip: true

        ScrollBar.vertical: ScrollBar {}

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

        delegate: ItemDelegate {
            width: listView.width
            height: 50

            background: Rectangle {
                color: index % 2 === 0 ? Constants.surfaceColor : Constants.alternateRowColor
            }

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

            onDoubleClicked: {
                if (model.isDir) {
                    ConnectionManager.listDirectory(model.path)
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
