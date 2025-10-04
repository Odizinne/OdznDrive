import QtQuick
import QtQuick.Controls.Material
import QtQuick.Controls.Material.impl
import QtQuick.Layouts
import Odizinne.OdznDrive

Item {
    id: footerBar
    height: 50 + 24
    property real storagePercentage: 0.0
    property string storageOccupied: "--"
    property string storageTotal: "--"

    Rectangle {
        anchors.fill: parent
        anchors.margins: 12
        color: Constants.surfaceColor
        radius: 4
        layer.enabled: true
        layer.effect: RoundedElevationEffect {
            elevation: 6
            roundedScale: 4
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 10
            spacing: 7

            ToolButton {
                Layout.preferredHeight: 50
                Layout.preferredWidth: 50
                Image {
                    anchors.centerIn: parent
                    sourceSize.height: 28
                    sourceSize.width: 28
                    source: "qrc:/icons/icon.png"
                }
            }

            TextField {
                Layout.preferredWidth: 300
                Layout.preferredHeight: 35
                placeholderText: "Filter..."
                onTextChanged: FilterProxyModel.filterText = text
            }

            Item {
                Layout.fillWidth: true
            }

            ColumnLayout {
                spacing: 4

                Item {
                    Layout.preferredWidth: 150
                    Layout.preferredHeight: 8

                    property real value: 0

                    Rectangle {
                        anchors.fill: parent
                        radius: 4
                        color: Constants.borderColor
                        opacity: 1

                        Rectangle {
                            width: parent.width * footerBar.storagePercentage
                            height: parent.height
                            radius: 4
                            color: footerBar.storagePercentage < 0.5 ? "#66BB6A" : footerBar.storagePercentage < 0.85 ? "#FF9800" : "#F44336"

                            Behavior on width {
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

                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: 4

                    Label {
                        text: footerBar.storageOccupied
                        font.pixelSize: 11
                        font.bold: true
                        opacity: 0.7
                    }

                    Label {
                        text: "/"
                        font.pixelSize: 11
                        opacity: 0.7
                    }

                    Label {
                        text: footerBar.storageTotal
                        font.pixelSize: 11
                        opacity: 0.7
                    }
                }
            }
        }
    }
}
