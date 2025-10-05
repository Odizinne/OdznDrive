#ifndef WINDOWSPLATFORM_H
#define WINDOWSPLATFORM_H

#include <QObject>
#include <qqml.h>

class WindowsPlatform : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
public:
    static WindowsPlatform* create(QQmlEngine *qmlEngine, QJSEngine *jsEngine);
    static WindowsPlatform* instance();

    Q_INVOKABLE bool setTitlebarColor(bool darkMode);

private:
    WindowsPlatform(QObject *parent = nullptr);
    static WindowsPlatform *s_instance;

#ifdef _WIN32
    bool m_titlebarColorMode;
#endif
};

#endif // WINDOWSPLATFORM_H
