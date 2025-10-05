import QtQuick
import QtQuick.Controls.Material
import QtQuick.Controls.Material.impl
import QtQuick.Layouts
import Odizinne.OdznDrive

Item {
    height: 50 + 24

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

            CustomButton {
                Image {
                    anchors.centerIn: parent
                    sourceSize.height: 24
                    sourceSize.width: 24
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

                CustomProgressBar {
                    Layout.preferredWidth: 150
                    Layout.preferredHeight: 8
                    Material.accent: Utils.storagePercentage < 0.5 ? "#66BB6A" : Utils.storagePercentage < 0.85 ? "#FF9800" : "#F44336"
                    value: Utils.storagePercentage
                }

                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: 4

                    Label {
                        text: Utils.storageOccupied
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
                        text: Utils.storageTotal
                        font.pixelSize: 11
                        opacity: 0.7
                    }
                }
            }
        }
    }
}
