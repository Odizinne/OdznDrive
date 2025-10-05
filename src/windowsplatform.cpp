#include "windowsplatform.h"

#ifdef _WIN32
#include <QApplication>
#include <QWindow>
#include <windows.h>
#include <dwmapi.h>
#include <QSettings>
#endif

WindowsPlatform* WindowsPlatform::s_instance = nullptr;


WindowsPlatform::WindowsPlatform(QObject *parent)
    :QObject(parent)
{
#ifdef _WIN32
    QSettings settings("Odizinne", "OdznDrive");
    m_titlebarColorMode = settings.value("darkMide", true).toBool();
#endif
}

WindowsPlatform* WindowsPlatform::create(QQmlEngine *qmlEngine, QJSEngine *jsEngine)
{
    Q_UNUSED(qmlEngine)
    Q_UNUSED(jsEngine)

    return instance();
}

WindowsPlatform* WindowsPlatform::instance()
{
    if (!s_instance) {
        s_instance = new WindowsPlatform();
    }
    return s_instance;
}

bool WindowsPlatform::setTitlebarColor(bool darkMode) {
#ifdef _WIN32
    if (darkMode == m_titlebarColorMode) {
        return true;
    }
    m_titlebarColorMode = darkMode;
    bool success = true;
    const QWindowList &windows = QApplication::topLevelWindows();
    for (QWindow* window : windows) {
        HWND hwnd = (HWND)window->winId();
        if (!hwnd) {
            success = false;
            continue;
        }
        bool windowSuccess = false;
        COLORREF color = darkMode ? RGB(42, 50, 57) : RGB(213, 220, 232);
        HRESULT hr = DwmSetWindowAttribute(hwnd, 35, &color, sizeof(color));
        if (SUCCEEDED(hr)) {
            windowSuccess = true;
        } else {
            BOOL winDarkMode = darkMode ? TRUE : FALSE;
            hr = DwmSetWindowAttribute(hwnd, 20, &winDarkMode, sizeof(winDarkMode));
            windowSuccess = SUCCEEDED(hr);
        }
        if (!windowSuccess) {
            success = false;
        }
    }

    return success;
#else

    // Not on Windows, so no effect

    m_titlebarColorMode = colorMode;

    return false;

#endif
}
