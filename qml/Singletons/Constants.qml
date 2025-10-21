pragma Singleton
import QtQuick

QtObject {
    property color accentColor: "#FF9F5A"
    property color primaryColor: "#E67E22"
    property color backgroundColor: UserSettings.darkMode ? "#2a3239" : "#d5dce8"
    property color altBackgroundColor: UserSettings.darkMode ? "#323a42" : "#d5dce8"
    property color surfaceColor: UserSettings.darkMode ? "#363f48" : "#e3ebf5"
    property color altSurfaceColor: UserSettings.darkMode ? "#363f48" : "#dfe7f2"
    property color listHeaderColor: UserSettings.darkMode ? "#3f4851" : "#c2cfe0"
    property color alternateRowColor: UserSettings.darkMode ? "#3a434c" : "#e0e8f2"
    property color borderColor: UserSettings.darkMode ? "#4f5861" : "#b5c3d6"

    property color scrollBarColor: UserSettings.darkMode ? "#4f5861" : "#b5c3d6"
    property color scrollBarHoveredColor: UserSettings.darkMode ? "#5f6871" : "#95a5ba"
    property color scrollBarPressedColor: UserSettings.darkMode ? "#6f7881" : "#8595aa"
    property color rippleHoverColor: "#AA5f6871"
    property color contrastedRippleHoverColor: Qt.lighter(Constants.headerGradientStart, 1.3)
    property color headerGradientStart: UserSettings.darkMode ? "#F0A860" : "#E07830"
    property color headerGradientStop: UserSettings.darkMode ? "#FFB880" : "#F0A060"

    property color treeDelegateHoverColor: UserSettings.darkMode ? "#4a5663" : "#c2cfe0"
}
