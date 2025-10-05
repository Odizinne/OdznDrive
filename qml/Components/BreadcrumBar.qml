pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.impl
import QtQuick.Layouts
import QtQuick.Controls.Material
import QtQuick.Controls.Material.impl
import Odizinne.OdznDrive
Item {
    id: root
    height: 45 + 24
    property var checkedItems: ({})
    property int checkedCount: 0
    signal showSettings()
    signal requestNewFolderDialog()
    signal requestMultiDeleteConfirmDialog()

    Rectangle {
        anchors.fill: parent
        anchors.margins: 12
        width: parent.width
        height: 45
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0.0
                color: Constants.headerGradientStart
            }
            GradientStop {
                position: 1.0
                color: Constants.headerGradientStop
            }
        }
        radius: 4
        layer.enabled: true
        layer.effect: RoundedElevationEffect {
            elevation: 6
            roundedScale: 4
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            CustomButton {
                visible: root.checkedCount === 0
                icon.source: "qrc:/icons/plus.svg"
                icon.color: "black"
                icon.width: 16
                icon.height: 16
                enabled: ConnectionManager.authenticated
                onClicked: root.requestNewFolderDialog()
                ToolTip.visible: hovered
                ToolTip.text: "New folder"
                rippleHoverColor: Constants.contrastedRippleHoverColor
            }

            CustomButton {
                visible: root.checkedCount === 0
                icon.source: "qrc:/icons/upload.svg"
                icon.color: "black"
                icon.width: 16
                icon.height: 16
                enabled: ConnectionManager.authenticated
                onClicked: Utils.openUploadDialog()
                ToolTip.visible: hovered
                ToolTip.text: "Upload files"
                rippleHoverColor: Constants.contrastedRippleHoverColor
            }

            CustomButton {
                visible: root.checkedCount === 0
                icon.source: "qrc:/icons/refresh.svg"
                icon.color: "black"
                icon.width: 16
                icon.height: 16
                rippleHoverColor: Constants.contrastedRippleHoverColor
                enabled: ConnectionManager.authenticated
                onClicked: {
                    ConnectionManager.listDirectory(FileModel.currentPath, UserSettings.foldersFirst)
                }
                ToolTip.visible: hovered
                ToolTip.text: "Refresh"
            }

            CustomButton {
                visible: root.checkedCount > 0
                icon.source: "qrc:/icons/download.svg"
                icon.width: 16
                icon.height: 16
                icon.color: "black"
                enabled: ConnectionManager.authenticated
                CustomButton {
                    visible: root.checkedCount > 0
                    icon.source: "qrc:/icons/download.svg"
                    icon.color: "black"
                    icon.width: 16
                    icon.height: 16
                    enabled: ConnectionManager.authenticated
                    onClicked: {
                        let items = Utils.getCheckedItems()

                        if (items.length === 1) {
                            if (items[0].isDir) {
                                Utils.openFolderDownloadDialog(items[0].path, items[0].name + ".zip")
                            } else {
                                Utils.openFileDownloadDialog(items[0].path, items[0].name)
                            }
                        } else {
                            Utils.openMultiDownloadDialog(Utils.getCheckedPaths())
                        }
                    }
                    ToolTip.visible: hovered
                    ToolTip.text: root.checkedCount === 1 ? "Download" : "Download as zip"
                    rippleHoverColor: Constants.contrastedRippleHoverColor
                }
                ToolTip.visible: hovered
                ToolTip.text: root.checkedCount === 1 ? "Download" : "Download as zip"
                rippleHoverColor: Constants.contrastedRippleHoverColor
            }

            CustomButton {
                visible: root.checkedCount > 0
                icon.source: "qrc:/icons/delete.svg"
                icon.width: 16
                icon.height: 16
                icon.color: "black"
                enabled: ConnectionManager.authenticated
                onClicked: root.requestMultiDeleteConfirmDialog()
                ToolTip.visible: hovered
                ToolTip.text: "Delete selected"
                rippleHoverColor: Constants.contrastedRippleHoverColor
            }

            Label {
                visible: root.checkedCount > 0
                text: root.checkedCount + (root.checkedCount === 1 ? " item selected" : " items selected")
                opacity: 0.7
                Layout.rightMargin: 4
                Material.foreground: "black"
            }

            Rectangle {
                Layout.preferredWidth: 1
                Layout.preferredHeight: 24
                color: "black"
                opacity: 0.3
            }

            Item {
                id: pathItem
                Layout.fillWidth: true
                implicitHeight: breadcrumbRow.implicitHeight
                clip: true

                Row {
                    id: measurementRow
                    visible: false
                    spacing: 6
                    height: parent.height

                    CustomButton {
                        text: ConnectionManager.serverName
                        flat: true
                        font.pixelSize: 13
                        implicitWidth: contentItem.implicitWidth + 20
                        rippleHoverColor: Constants.contrastedRippleHoverColor
                    }

                    Repeater {
                        model: Utils.getPathSegments()

                        Row {
                            id: pathMeasureItem
                            required property string modelData
                            spacing: 6

                            IconImage {
                                source: "qrc:/icons/right.svg"
                                sourceSize.width: 10
                                sourceSize.height: 10
                                color: "black"
                            }

                            CustomButton {
                                text: pathMeasureItem.modelData
                                flat: true
                                font.pixelSize: 13
                                Material.foreground: "black"
                                implicitWidth: contentItem.implicitWidth + 20
                                rippleHoverColor: Constants.contrastedRippleHoverColor
                            }
                        }
                    }
                }

                property bool needsEllipsis: measurementRow.implicitWidth > width - 20

                Row {
                    id: breadcrumbRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    CustomButton {
                        id: rootButton
                        text: ConnectionManager.serverName
                        flat: true
                        font.pixelSize: 13
                        implicitWidth: contentItem.implicitWidth + 20
                        onClicked: ConnectionManager.listDirectory("", UserSettings.foldersFirst)
                        Material.foreground: "black"
                        font.bold: Utils.getPathSegments().length === 0
                        opacity: Utils.getPathSegments().length === 0 || rootHover.hovered ? 1 : 0.7
                        rippleHoverColor: Constants.contrastedRippleHoverColor

                        HoverHandler {
                            id: rootHover
                        }
                    }

                    Loader {
                        active: pathItem.needsEllipsis && Utils.getPathSegments().length > 1
                        visible: active
                        sourceComponent: Row {
                            spacing: 6

                            IconImage {
                                source: "qrc:/icons/right.svg"
                                sourceSize.width: 10
                                sourceSize.height: 10
                                anchors.verticalCenter: parent.verticalCenter
                                opacity: 0.7
                                color: "black"
                            }

                            CustomButton {
                                text: "..."
                                flat: true
                                font.pixelSize: 13
                                implicitWidth: contentItem.implicitWidth + 20
                                rippleHoverColor: Constants.contrastedRippleHoverColor
                                opacity: ellipsisHover.hovered ? 1 : 0.7
                                onClicked: hiddenPathsMenu.popup()
                                Material.foreground: "black"

                                HoverHandler {
                                    id: ellipsisHover
                                }

                                CustomMenu {
                                    id: hiddenPathsMenu
                                    width: 200

                                    Instantiator {
                                        model: Utils.getHiddenSegments()
                                        delegate: MenuItem {
                                            required property string modelData
                                            required property int index
                                            text: modelData
                                            onClicked: {
                                                ConnectionManager.listDirectory(Utils.getPathUpToHiddenIndex(index), UserSettings.foldersFirst)
                                            }
                                        }
                                        onObjectAdded: (index, object) => hiddenPathsMenu.insertItem(index, object)
                                        onObjectRemoved: (index, object) => hiddenPathsMenu.removeItem(object)
                                    }
                                }
                            }
                        }
                    }

                    Loader {
                        active: pathItem.needsEllipsis && Utils.getPathSegments().length > 0
                        visible: active
                        sourceComponent: Row {
                            spacing: 6

                            IconImage {
                                source: "qrc:/icons/right.svg"
                                sourceSize.width: 10
                                sourceSize.height: 10
                                anchors.verticalCenter: parent.verticalCenter
                                color: "black"
                                opacity: 0.7
                            }

                            CustomButton {
                                text: Utils.getLastSegment()
                                flat: true
                                font.pixelSize: 13
                                implicitWidth: contentItem.implicitWidth + 20
                                rippleHoverColor: Constants.contrastedRippleHoverColor
                                font.bold: true
                                opacity: lastSegmentHover.hovered ? 1 : 0.7
                                Material.foreground: "black"
                                onClicked: {
                                    ConnectionManager.listDirectory(FileModel.currentPath, UserSettings.foldersFirst)
                                }

                                HoverHandler {
                                    id: lastSegmentHover
                                }
                            }
                        }
                    }

                    Repeater {
                        id: allSegmentsRepeater
                        model: pathItem.needsEllipsis ? [] : Utils.getPathSegments()

                        Row {
                            id: pathBtn
                            required property string modelData
                            required property int index
                            spacing: 6

                            IconImage {
                                source: "qrc:/icons/right.svg"
                                sourceSize.width: 10
                                sourceSize.height: 10
                                anchors.verticalCenter: parent.verticalCenter
                                color: "black"
                                opacity: 0.7
                            }

                            CustomButton {
                                text: pathBtn.modelData
                                flat: true
                                font.pixelSize: 13
                                implicitWidth: contentItem.implicitWidth + 20
                                rippleHoverColor: Constants.contrastedRippleHoverColor
                                font.bold: pathBtn.index === allSegmentsRepeater.count - 1
                                opacity: pathBtn.index === allSegmentsRepeater.count - 1 || pathBtnHover.hovered ? 1 : 0.7
                                onClicked: {
                                    ConnectionManager.listDirectory(Utils.getPathUpToIndex(pathBtn.index), UserSettings.foldersFirst)
                                }
                                Material.foreground: "black"

                                HoverHandler {
                                    id: pathBtnHover
                                }
                            }
                        }
                    }
                }
            }

            CustomButton {
                icon.source: UserSettings.listView ? "qrc:/icons/grid.svg" : "qrc:/icons/list.svg"
                icon.width: 16
                icon.height: 16
                onClicked: UserSettings.listView = !UserSettings.listView
                icon.color: "black"
                ToolTip.visible: hovered
                ToolTip.text: UserSettings.listView ? "Tile view" : "List view"
                rippleHoverColor: Constants.contrastedRippleHoverColor
            }

            CustomButton {
                icon.source: "qrc:/icons/cog.svg"
                icon.width: 16
                icon.height: 16
                onClicked: root.showSettings()
                ToolTip.visible: hovered
                ToolTip.text: "Settings"
                icon.color: "black"
                rippleHoverColor: Constants.contrastedRippleHoverColor
            }
        }
    }
}
