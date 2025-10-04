pragma Singleton
import QtQuick
import QtQuick.Controls.Material

QtObject {
    property bool darkMode: true
    readonly property int materialTheme: darkMode ? Material.Dark : Material.Light
    property color backgroundColor: darkMode ? "#191c21" : "#f6f8fc"
    property color surfaceColor: darkMode ? "#212530" : "#ffffff"
    property color listHeaderColor: darkMode ? "#282c35" : "#eff2f8"
    property color alternateRowColor: darkMode ? "#25292f" : "#f4f6fb"
    property color borderColor: darkMode ? "#383c45" : "#d8dde8"
}
