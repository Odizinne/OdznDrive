import QtQuick
import QtQuick.Controls.Material
import Odizinne.OdznDrive

Item {
    id: control
    implicitWidth: 80
    implicitHeight: 80

    property bool spinning: true
    property bool filling: false
    property real fillProgress: 0.0

    signal fillComplete()

    Rectangle {
        id: background
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        radius: width / 2
        color: "transparent"
        border.width: 4
        border.color: Constants.borderColor
        opacity: 0.3
    }

    Rectangle {
        id: spinner
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        radius: width / 2
        color: "transparent"
        border.width: 4
        border.color: Material.accent
        visible: !control.filling

        Rectangle {
            width: parent.width
            height: parent.height
            radius: width / 2
            color: "transparent"
            clip: true

            Rectangle {
                width: parent.width
                height: parent.height / 4
                color: Material.accent
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                visible: control.spinning
            }
        }

        rotation: 0

        RotationAnimator on rotation {
            running: control.spinning && !control.filling
            from: 0
            to: 360
            duration: 1200
            loops: Animation.Infinite
            easing.type: Easing.Linear
        }
    }

    Canvas {
        id: fillCanvas
        anchors.fill: parent
        visible: control.filling
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()

            var centerX = width / 2
            var centerY = height / 2
            var radius = (width / 2) - 2

            // Draw filled arc
            ctx.beginPath()
            ctx.arc(centerX, centerY, radius, -Math.PI / 2, -Math.PI / 2 + (control.fillProgress * 2 * Math.PI), false)
            ctx.lineWidth = 4
            ctx.strokeStyle = Material.accent
            ctx.stroke()
        }

        Connections {
            target: control
            function onFillProgressChanged() {
                fillCanvas.requestPaint()
            }
        }
    }

    SequentialAnimation {
        id: fillAnimation
        running: control.filling

        NumberAnimation {
            target: control
            property: "fillProgress"
            from: 0
            to: 1
            duration: 800
            easing.type: Easing.OutCubic
        }

        ScriptAction {
            script: control.fillComplete()
        }
    }

    function startFilling() {
        control.spinning = false
        control.filling = true
        control.fillProgress = 0
    }

    function reset() {
        control.filling = false
        control.fillProgress = 0
        control.spinning = true
    }
}
