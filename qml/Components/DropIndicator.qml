import QtQuick
import QtQuick.Controls.Material
import Odizinne.OdznDrive

Rectangle {
    color: Material.primary
    radius: 4
    opacity: Utils.dropAreaVisible ? 0.8 : 0
    visible: opacity !== 0

    Behavior on opacity {
        NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
    }

    Label {
        anchors.centerIn: parent
        text: "Drop files here to upload"
        font.pixelSize: 24
        font.bold: true
        color: Material.foreground
    }
}
