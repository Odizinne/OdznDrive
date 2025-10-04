pragma Singleton
import QtQuick

QtObject {
    property color backgroundColor: UserSettings.darkMode ? "#2a3239" : "#e8ecf4"
    property color surfaceColor: UserSettings.darkMode ? "#363f48" : "#ffffff"
    property color listHeaderColor: UserSettings.darkMode ? "#3f4851" : "#d9e1ed"
    property color alternateRowColor: UserSettings.darkMode ? "#3a434c" : "#f0f4f9"
    property color borderColor: UserSettings.darkMode ? "#4f5861" : "#bcc5d4"

    property color scrollBarColor: UserSettings.darkMode ? "#4f5861" : "#bcc5d4"
    property color scrollBarHoveredColor: UserSettings.darkMode ? "#5f6871" : "#9ca8b7"
    property color scrollBarPressedColor: UserSettings.darkMode ? "#6f7881" : "#8c98a7"
}
