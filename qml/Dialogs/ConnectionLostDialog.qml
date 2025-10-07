import QtQuick.Controls.Material
import QtQuick.Layouts
import QtQuick
import Odizinne.OdznDrive

CustomDialog {
    title: "Connection lost"

    ColumnLayout {
        anchors.fill: parent
        spacing: 10
        CustomProgressBar {
            indeterminate: true
        }

        Label {
            text: "Attempting to reconnect..."
        }
    }
}
