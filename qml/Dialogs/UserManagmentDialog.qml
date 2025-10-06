import QtQuick
import QtQuick.Layouts
import Odizinne.OdznDrive
import QtQuick.Controls.Material
import QtQuick.Controls.Material.impl

CustomDialog {
    id: userManagmentDialog
    anchors.centerIn: parent
    height: 550
    width: 600
    standardButtons: Qt.Close
    onOpened: ConnectionManager.getUserList()
    ColumnLayout {
        id: mainLyt
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.bottomMargin: 10
            Label {
                text: "User managment"
                font.bold: true
                font.pixelSize: 16
                Layout.fillWidth: true
            }

            CustomButton {
                icon.width: 16
                icon.height: 16
                icon.source: "qrc:/icons/new.svg"
                onClicked: userAddDialog.open()
            }
        }

        Rectangle {
            Layout.bottomMargin: 10
            Layout.preferredHeight: 45
            Layout.fillWidth: true
            color: Constants.headerGradientStart
            radius: 4
            clip: true
            layer.enabled: true
            layer.effect: RoundedElevationEffect {
                elevation: 6
                roundedScale: 4
            }
            RowLayout {
                height: 45
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                anchors.fill: parent
                Label {
                    text: "Username"
                    Layout.fillWidth: true
                    Material.foreground: "black"
                    font.bold: true
                }

                Label {
                    text: "Storage"
                    Layout.maximumWidth: 80
                    Layout.minimumWidth: 80
                    Material.foreground: "black"
                    font.bold: true
                }

                Label {
                    text: "Admin"
                    Layout.maximumWidth: 70
                    Layout.minimumWidth: 70
                    Material.foreground: "black"
                    font.bold: true
                }

                Label {
                    text: "Actions"
                    Layout.maximumWidth: 70
                    Layout.minimumWidth: 70
                    Material.foreground: "black"
                    font.bold: true
                }
            }
        }

        CustomScrollView {
            id: scrollView
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: userListView
                width: scrollView.width
                height: contentHeight
                model: UserModel
                headerPositioning: ListView.OverlayHeader
                contentHeight: contentItem.childrenRect.height
                contentWidth: width
                clip: true
                spacing: 5
                interactive: false
                delegate: Item {
                    id: userDel
                    width: userListView.width
                    height: 45
                    required property var model
                    required property int index
                    HoverHandler {
                        id: delHover
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: delHover.hovered ? Constants.borderColor : "transparent"
                        opacity: delHover.hovered ? 1 : 0
                        radius: 4
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.OutQuad
                            }
                        }
                    }

                    RowLayout {
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        anchors.fill: parent
                        Label {
                            text: userDel.model.username
                            Layout.fillWidth: true
                        }

                        Label {
                            text: Utils.formatSize(userDel.model.storageLimit)
                            Layout.maximumWidth: 80
                            Layout.minimumWidth: 80
                        }

                        Item {
                            Layout.preferredHeight: 45
                            Layout.maximumWidth: 70
                            Layout.minimumWidth: 70
                            CheckBox {
                                anchors.centerIn: parent
                                checked: userDel.model.isAdmin
                                enabled: false
                                anchors.horizontalCenterOffset: -12
                            }
                        }

                        RowLayout {
                            Layout.maximumWidth: 70
                            Layout.minimumWidth: 70
                            opacity: delHover.hovered ? 1 : 0
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.OutQuad
                                }
                            }

                            CustomButton {
                                icon.width: 16
                                icon.height: 16
                                icon.source: "qrc:/icons/edit.svg"
                                enabled: ConnectionManager.serverName !== userDel.model.username
                                onClicked: userAddDialog.openInEditMode(userDel.model.username, userDel.model.password, userDel.model.storageLimit, userDel.model.isAdmin)
                            }

                            CustomButton {
                                icon.width: 16
                                icon.height: 16
                                icon.source: "qrc:/icons/delete.svg"
                                enabled: ConnectionManager.serverName !== userDel.model.username
                                onClicked: {
                                    confirmDeleteUserDialog.username = userDel.model.username
                                    confirmDeleteUserDialog.open()
                                }
                            }
                        }
                    }

                    Separator {
                        anchors.top: userDel.bottom
                        visible: userDel.index !== userListView.count
                        color: Constants.borderColor
                    }
                }
            }
        }

        TextField {
            placeholderText: "Filter..."
            Layout.fillWidth: true
            Layout.preferredHeight: 35
        }
    }
}
