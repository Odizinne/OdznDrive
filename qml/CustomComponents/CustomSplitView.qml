pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls.Material
import Odizinne.OdznDrive

SplitView {
    id: control
    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding)
    orientation: Qt.Horizontal
    property int handleSpacing: 0

    handle: Loader {
        sourceComponent: UserSettings.compactSidePane ? emptyHandle : defaultHandle
    }

    Component {
        id: emptyHandle
        Item {
            implicitWidth: 10
            implicitHeight: 0
        }
    }

    Component {
        id: defaultHandle
        Item {
            id: cont
            implicitWidth: 4 + control.handleSpacing * 2
            implicitHeight: control.height
            Rectangle {
                id: handleRect
                radius: 4
                anchors.fill: parent
                anchors.topMargin: margins
                anchors.bottomMargin: margins
                anchors.leftMargin: control.handleSpacing
                anchors.rightMargin: control.handleSpacing
                property int margins: !cont.SplitHandle.pressed && !cont.SplitHandle.hovered ? cont.height / 24 : 6
                color: Constants.scrollBarPressedColor
                opacity: cont.SplitHandle.pressed ? 0.3 :
                         cont.SplitHandle.hovered ? 1 :
                         UserSettings.darkMode ? 0.2 : 0.4
                Behavior on margins {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }
}
