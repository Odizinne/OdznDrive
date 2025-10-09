import QtQuick.Controls.Material
import Odizinne.OdznDrive

CustomMenu {
    width: 200

    MenuItem {
        text: "Navigate Up"
        icon.source: "qrc:/icons/up.svg"
        icon.width: 16
        icon.height: 16
        onClicked: {
            ConnectionManager.listDirectory(FileModel.getParentPath(), UserSettings.foldersFirst)
        }
    }
}
