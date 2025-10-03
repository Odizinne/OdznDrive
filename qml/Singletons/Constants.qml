pragma Singleton
import QtQuick
import QtQuick.Controls.Material

QtObject {
    property bool darkMode: true

    // Use Material theme
    readonly property int materialTheme: darkMode ? Material.Dark : Material.Light

    // Only define colors not well handled by Material
    property color backgroundColor: darkMode ? "#1e1e1e" : "#fafafa"
    property color surfaceColor: darkMode ? "#252526" : "#ffffff"
    property color listHeaderColor: darkMode ? "#2d2d30" : "#f5f5f5"
    property color alternateRowColor: darkMode ? "#2a2a2a" : "#f9f9f9"
}
