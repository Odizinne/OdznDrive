pragma Singleton
import QtCore

Settings {
    property bool autoconnect: false
    property string serverUrl: "ws://localhost:8888"
    property string serverPassword: ""
    property bool listView: true
    property bool foldersFirst: true
    property bool darkMode: true
}
