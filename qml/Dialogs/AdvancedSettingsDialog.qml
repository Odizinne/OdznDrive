import QtQuick.Controls.Material
import QtQuick
import Odizinne.OdznDrive
import QtQuick.Layouts

CustomDialog {
    title: "Advanced Settings"
    width: 500
    standardButtons: Dialog.Close
    ColumnLayout {
        anchors.fill: parent
        spacing: 15

        RowLayout {
            Label {
                Layout.fillWidth: true
                text: "Ask where to download"
            }

            Switch {
                checked: UserSettings.askWhereToDownload
                onClicked: UserSettings.askWhereToDownload = checked
            }
        }

        RowLayout {
            enabled: !UserSettings.askWhereToDownload
            Label {
                Layout.fillWidth: true
                text: "Download folder"
            }

            TextField {
                id: downloadFolderText
                Layout.preferredWidth: 200
                Layout.preferredHeight: 35
                text: Utils.toNativeFilePath(UserSettings.downloadFolderPath)
                readOnly: true
                font.pixelSize: 10
            }

            CustomButton {
                icon.width: 16
                icon.height: 16
                icon.source: "qrc:/icons/browse.svg"
                onClicked: {
                    var folder = FileDialogHelper.getExistingDirectory("Select Download Folder")
                    if (folder !== "") {
                        downloadFolderText.text = folder
                        UserSettings.downloadFolderPath = folder
                    }
                }
            }
        }
    }
}
