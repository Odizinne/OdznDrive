pragma Singleton
import QtQuick
import QtQuick.Controls.Material

QtObject {
    property bool darkMode: true
    readonly property int materialTheme: darkMode ? Material.Dark : Material.Light
    property color backgroundColor: darkMode ? "#1e1e1e" : "#fafafa"
    property color surfaceColor: darkMode ? "#252526" : "#ffffff"
    property color listHeaderColor: darkMode ? "#2d2d30" : "#f5f5f5"
    property color alternateRowColor: darkMode ? "#2a2a2a" : "#f9f9f9"
    property color borderColor: darkMode ? "#3e3e3e" : "#e0e0e0"
}
