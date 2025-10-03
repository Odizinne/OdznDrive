import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    visible: false
    color: "#f5f5f5"
    border.color: "#e0e0e0"
    border.width: 1
    
    property string fileName: ""
    property int progress: 0
    property bool isUpload: true
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 5
        
        Label {
            text: (root.isUpload ? "Uploading: " : "Downloading: ") + root.fileName
            elide: Text.ElideMiddle
            Layout.fillWidth: true
        }
        
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            
            ProgressBar {
                Layout.fillWidth: true
                value: root.progress / 100
            }
            
            Label {
                text: root.progress + "%"
            }
        }
    }
}