import QtQuick
import QtQuick.Controls.Material
import QtQuick.Layouts
import Odizinne.OdznDrive

RowLayout {
    spacing: 10
    visible: ConnectionManager.eta !== "" || ConnectionManager.speed !== ""

    Label {
        text: "Speed: " + ConnectionManager.speed
        opacity: 0.7
    }

    Item {
        Layout.fillWidth: true
    }

    Label {
        text: "ETA: " + ConnectionManager.eta
        opacity: 0.7
    }
}
