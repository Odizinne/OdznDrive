import QtQuick
import QtQuick.Controls.Material

Dialog {
    width: 400
    modal: true
    Material.roundedScale: Material.ExtraSmallScale
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
