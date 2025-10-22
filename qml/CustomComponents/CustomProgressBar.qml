import QtQuick.Controls.Material
import QtQuick
Item {
    id: control
    implicitWidth: vertical ? 8 : 150
    implicitHeight: vertical ? 150 : 8
    property real value: 0
    property real from: 0
    property real to: 1
    property bool indeterminate: false
    property bool vertical: false
    readonly property real normalizedValue: {
        if (to === from) return 1
        return Math.max(0, Math.min(1, (value - from) / (to - from)))
    }
    Rectangle {
        anchors.fill: parent
        radius: 4
        color: Material.background
        opacity: 1
        Rectangle {
            width: control.vertical ? parent.width : (control.indeterminate ? parent.width * widthFactor : parent.width * control.normalizedValue)
            height: control.vertical ? (control.indeterminate ? parent.height * widthFactor : parent.height * control.normalizedValue) : parent.height
            radius: 4
            color: Material.accent
            x: control.vertical ? 0 : (control.indeterminate ? (parent.width - width) * position : 0)
            y: control.vertical ? (control.indeterminate ? (parent.height - height) * position : parent.height - height) : 0
            property real position
            property real widthFactor
            SequentialAnimation on position {
                running: control.indeterminate
                loops: Animation.Infinite
                NumberAnimation {
                    from: 0
                    to: 1
                    duration: 1500
                    easing.type: Easing.InOutCubic
                }
            }
            SequentialAnimation on widthFactor {
                running: control.indeterminate
                loops: Animation.Infinite
                NumberAnimation {
                    from: 0
                    to: 0.3
                    duration: 750
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    from: 0.3
                    to: 0
                    duration: 750
                    easing.type: Easing.InCubic
                }
            }
            Behavior on width {
                enabled: !control.indeterminate && !control.vertical
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on height {
                enabled: !control.indeterminate && control.vertical
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: 200
                }
            }
        }
    }
}
