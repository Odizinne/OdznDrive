import QtQuick
import QtQuick.Controls.Material
import QtQuick.Controls.Material.impl
import QtQuick.Layouts
import Odizinne.OdznDrive

Item {
    id: footer
    height: 50 + 24
    signal showUserManagmentDialog()
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
                CustomButton {
                    id: menuButton
                    onClicked: menu.visible ? menu.close() : menu.open()
                    icon.source: "qrc:/icons/cog.svg"
                    icon.width: 16
                    icon.height: 16
                    CustomMenu {
                        id: menu
                        width: 200
                        y: menuButton.y - menu.height - 15
                        x: menuButton.x - 8

                        MenuItem {
                            text: ConnectionManager.serverName
                            enabled: false
                        }
                        MenuItem {
                            text: "Users managment"
                            implicitHeight: ConnectionManager.isAdmin ? Math.max(implicitBackgroundHeight + topInset + bottomInset,
                                                     implicitContentHeight + topPadding + bottomPadding,
                                                     implicitIndicatorHeight + topPadding + bottomPadding) : 0
                            enabled: ConnectionManager.isAdmin
                            visible: ConnectionManager.isAdmin
                            onClicked: footer.showUserManagmentDialog()
                        }
                        MenuSeparator {}
                        MenuItem {
                            text: "Folders first"
                            checked: UserSettings.foldersFirst
                            checkable: true
                            onClicked: UserSettings.foldersFirst = checked
                        }
                        MenuItem {
                            text: "Dark mode"
                            checkable: true
                            checked: UserSettings.darkMode
                            onClicked: {
                                UserSettings.darkMode = checked
                                WindowsPlatform.setTitlebarColor(checked)
                            }
                        }
                        MenuSeparator {}
                        MenuItem {
                            text: "Disconnect"
                            onClicked: {
                                menu.close()
                                ConnectionManager.disconnect()
                            }
                        }
                        MenuItem {
                            text: "Exit"
                            onClicked: Qt.quit()
                        }
                    }
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
