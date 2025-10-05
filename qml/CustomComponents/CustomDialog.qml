import QtQuick
import QtQuick.Controls.Material
import Odizinne.OdznDrive

Dialog {
    width: 400
    modal: true
    Material.roundedScale: Material.ExtraSmallScale
    Material.background: Constants.surfaceColor
    Overlay.modal: Rectangle {
        color: "#66000000"
        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }
        }
    }
    Overlay.modeless: Rectangle {
        color: "#66000000"
        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }
        }
    }
}
