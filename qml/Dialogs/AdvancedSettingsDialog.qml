import QtQuick.Controls.Material
import QtQuick
import Odizinne.OdznDrive
import QtQuick.Layouts

CustomDialog {
    title: "Advanced Settings"
    ColumnLayout {
        anchors.fill: parent
        spacing: 10
        RowLayout {
            Label {
                Layout.fillWidth: true
                text: "Download folder"
            }
        }
    }
}
