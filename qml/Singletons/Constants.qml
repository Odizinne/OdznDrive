pragma Singleton
import QtQuick

QtObject {
    property color backgroundColor: UserSettings.darkMode ? "#20252b" : "#e8ecf4"
    property color surfaceColor: UserSettings.darkMode ? "#2b303a" : "#ffffff"
    property color listHeaderColor: UserSettings.darkMode ? "#2f353f" : "#d9e1ed"
    property color alternateRowColor: UserSettings.darkMode ? "#2c313a" : "#f0f4f9"
    property color borderColor: UserSettings.darkMode ? "#40454e" : "#bcc5d4"
}
