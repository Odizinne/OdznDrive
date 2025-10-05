import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Material
import Odizinne.OdznDrive

CustomDialog {
    id: root
    title: "Settings"
    standardButtons: Dialog.NoButton
    closePolicy: ConnectionManager.connected ? Popup.CloseOnEscape | Popup.CloseOnPressOutside : Popup.NoAutoClose
    modal: true

    footer: DialogButtonBox {
        Button {
            flat: true
            text: "Close"
            enabled: ConnectionManager.connected
            onClicked: root.close()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        RowLayout {
            Label {
                text: "Sort folders before files"
                Layout.fillWidth: true
            }

            Switch {
                checked: UserSettings.foldersFirst
                onClicked: {
                    UserSettings.foldersFirst = checked
                    ConnectionManager.listDirectory(FileModel.currentPath, checked)
                }
            }
        }

        RowLayout {
            Label {
                text: "Dark mode"
                Layout.fillWidth: true
            }

            Switch {
                checked: UserSettings.darkMode
                onClicked: {
                    UserSettings.darkMode = checked
                    WindowsPlatform.setTitlebarColor(checked)
                }
            }
        }
    }
}
