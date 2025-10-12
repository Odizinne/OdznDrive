import QtQuick
import QtQuick.Controls.Material
import QtQuick.Controls.impl
import QtQuick.Layouts
import Odizinne.OdznDrive

CustomDialog {
    id: root
    width: 400
    title: "Override Warning"
    standardButtons: Dialog.Yes | Dialog.Cancel

    property var conflictingFiles: []
    property var pendingUploadData: null

    signal proceedWithUpload()

    onAccepted: {
        if (doNotShowCheckBox.checked) {
            UserSettings.warnOnOverride = false
        }
        root.proceedWithUpload()
    }

    onRejected: {
        if (doNotShowCheckBox.checked) {
            UserSettings.warnOnOverride = false
        }
        root.pendingUploadData = null
    }

    contentItem: ColumnLayout {
        spacing: 16
        width: parent.width

        Label {
            Layout.fillWidth: true
            text: conflictingFiles.length === 1
                  ? "The following file already exists and will be overridden:"
                  : "The following files already exist and will be overridden:"
            wrapMode: Text.WordWrap
            font.pixelSize: 13
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(fileListView.contentHeight + 20, 200)
            color: Constants.surfaceColor
            radius: 4
            border.color: Constants.borderColor
            border.width: 1

            CustomScrollView {
                anchors.fill: parent
                anchors.margins: 10

                ListView {
                    id: fileListView
                    spacing: 4
                    clip: true
                    interactive: contentHeight > height

                    model: root.conflictingFiles

                    delegate: RowLayout {
                        width: fileListView.width
                        spacing: 8

                        required property string modelData

                        IconImage {
                            Layout.preferredWidth: 16
                            Layout.preferredHeight: 16
                            source: "qrc:/icons/types/unknow.svg"
                            color: Material.foreground
                        }

                        Label {
                            Layout.fillWidth: true
                            text: modelData
                            elide: Text.ElideMiddle
                            font.pixelSize: 12
                        }
                    }
                }
            }
        }

        Label {
            Layout.fillWidth: true
            text: "Do you want to proceed and override?"
            wrapMode: Text.WordWrap
            font.pixelSize: 13
            font.bold: true
        }

        CheckBox {
            id: doNotShowCheckBox
            text: "Do not show this warning again"
            font.pixelSize: 12
        }
    }
}
