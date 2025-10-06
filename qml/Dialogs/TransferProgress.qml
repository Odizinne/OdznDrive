import QtQuick
import QtQuick.Controls.Material
import QtQuick.Layouts
import Odizinne.OdznDrive
Rectangle {
    id: root
    visible: false
    color: Constants.surfaceColor

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

            CustomProgressBar {
                Layout.fillWidth: true
                value: root.progress / 100
            }

            Label {
                text: root.progress + "%"
            }
        }
    }
}
