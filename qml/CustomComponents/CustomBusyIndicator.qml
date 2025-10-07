import QtQuick
import QtQuick.Controls.Material
import Odizinne.OdznDrive

Item {
    id: control
    implicitWidth: 200
    implicitHeight: 8

    property real value: 0
    property bool indeterminate: true

    signal complete()

    onValueChanged: {
        if (value >= 1.0 && !indeterminate) {
            complete()
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 4
        color: Constants.borderColor
        opacity: 1

        Rectangle {
            id: progressBar
            width: control.indeterminate ? parent.width * widthFactor : parent.width * control.value
            height: parent.height
            radius: 4
            color: Material.accent
            x: control.indeterminate ? (parent.width - width) * position : 0

            // FIX: Removed the initial binding ": 0"
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
                NumberAnimation {
                    from: 1
                    to: 0
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
                enabled: !control.indeterminate
                NumberAnimation {
                    duration: 800
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on x {
                enabled: !control.indeterminate
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    function startFilling() {
        control.indeterminate = false
        control.value = 0
        fillTimer.start()
    }

    function reset() {
        control.indeterminate = true
        control.value = 0
    }

    Timer {
        id: fillTimer
        interval: 50
        onTriggered: {
            control.value = 1
        }
    }
}
