pragma Singleton
import QtCore
import QtQml

Settings {
    property bool firstRun: true
    property bool autoconnect: false
    property string serverUrl: "ws://localhost:8888"
    property string serverUsername: ""
    property string serverPassword: ""
    property bool listView: true
    property bool foldersFirst: true
    property bool darkMode: true
    property bool askWhereToDownload: false
    property string downloadFolderPath:
        (Qt.platform.os === "linux" ? StandardPaths.writableLocation(StandardPaths.HomeLocation) : StandardPaths.writableLocation(StandardPaths.DocumentsLocation)) + "/OdznDrive Downloads"
    property bool compactSidePane: false
}
