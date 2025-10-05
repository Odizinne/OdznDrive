import QtQuick
import QtQuick.Controls.Material

Rectangle {
    id: dragIndicator
    visible: false
    width: dragLabel.implicitWidth + 20
    height: 40
    color: Material.primary
    radius: 4
    opacity: 0.7
    z: 1000
    parent: Overlay.overlay
    property string text: ""

    Label {
        id: dragLabel
        anchors.centerIn: parent
        color: Material.foreground
        font.bold: true
        text: dragIndicator.text
    }
}
