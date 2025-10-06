import QtQuick
import QtQuick.Controls.Material
import Odizinne.OdznDrive

Flickable {
    id: control

    boundsMovement: Flickable.StopAtBounds
    boundsBehavior: Flickable.StopAtBounds
    contentWidth: width
    clip: true
    contentHeight: contentItem.childrenRect.height
    acceptedButtons: Qt.NoButton
    ScrollBar.vertical: ScrollBar {
        id: vBar
        parent: control
        anchors.right: control.right
        anchors.top: control.top
        anchors.bottom: control.bottom

        policy: control.contentHeight > control.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff

        contentItem: Rectangle {
            implicitWidth: vBar.interactive ? 10 : 4
            implicitHeight: vBar.interactive ? 10 : 4
            radius: 4
            color: vBar.pressed ? Constants.scrollBarColor :
                   vBar.interactive && vBar.hovered ? Constants.scrollBarPressedColor :
                   Constants.scrollBarHoveredColor
            opacity: 1

            Behavior on color {
                ColorAnimation { duration: 150 }
            }

            Behavior on opacity {
                NumberAnimation { duration: 150 }
            }

            Behavior on implicitWidth {
                NumberAnimation { duration: 100 }
            }
        }

        background: Item {}
    }

    MouseArea {
        anchors.fill: parent
        preventStealing: true
    }
}
