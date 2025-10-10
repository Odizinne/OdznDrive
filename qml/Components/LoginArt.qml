pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Material
import Qt5Compat.GraphicalEffects

Item {
    id: bubbles
    anchors.fill: parent
    property alias model: repeater.model
    property var bubblesColor: [
        Qt.lighter(Material.color(Material.Blue), 1.2),
        Qt.lighter(Material.color(Material.DeepPurple), 1.2),
        Qt.lighter(Material.color(Material.Orange), 1.2)
    ]
    Repeater {
        id: repeater
        delegate: Rectangle {
            id: bubbleShape
            width: model.size
            height: model.size
            radius: width / 2
            color: "transparent"

            required property var model

            x: parent.width / 2 + model.offsetX
            y: parent.height / 2 + model.offsetY
            property color bubbleColor: bubbles.bubblesColor[model.colorIndex]

            RadialGradient {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.lighter(bubbleShape.bubbleColor, 1.2) }
                    GradientStop { position: 1.0; color: bubbleShape.bubbleColor }
                }
                horizontalRadius: width / 2
                verticalRadius: height / 2
            }

            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: bubbleShape.width
                    height: bubbleShape.height
                    radius: bubbleShape.width / 2
                    color: "white"
                }
            }
        }
    }
}
