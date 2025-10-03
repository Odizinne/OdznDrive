import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Odizinne.OdznDriveClient

Rectangle {
    id: root
    color: "white"
    
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
            color: "#f0f0f0"
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
                    Layout.preferredWidth: 100
                }
            }
        }
        
        delegate: ItemDelegate {
            width: listView.width
            height: 50
            
            background: Rectangle {
                color: index % 2 === 0 ? "white" : "#fafafa"
                border.color: parent.hovered ? "#2196F3" : "transparent"
                border.width: 1
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
                }
                
                Label {
                    text: formatDate(model.modified)
                    Layout.preferredWidth: 180
                }
                
                RowLayout {
                    Layout.preferredWidth: 100
                    spacing: 5
                    
                    Button {
                        text: "↓"
                        visible: !model.isDir
                        onClicked: {
                            root.Window.window.showDownloadDialog(model.path)
                        }
                    }
                    
                    Button {
                        text: "✕"
                        onClicked: {
                            root.Window.window.showDeleteConfirm(model.path, model.isDir)
                        }
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
            color: "#999"
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