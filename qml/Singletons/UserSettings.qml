pragma Singleton
import QtCore

Settings {
    property bool firstRun: true
    property bool autoconnect: false
    property string serverUrl: "ws://localhost:8888"
    property string serverUsername: ""
    property string serverPassword: ""
    property bool listView: true
    property bool foldersFirst: true
    property bool darkMode: true
    property string downloadFolderPath: StandardPaths.writableLocation(StandardPaths.DocumentsLocation) + "/OdznDrive Downloads"
}
