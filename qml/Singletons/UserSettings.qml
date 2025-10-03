pragma Singleton
import QtCore

Settings {
    property bool autoconnect: false
    property string serverUrl: "ws://localhost:8888"
    property string serverPassword: ""
}
