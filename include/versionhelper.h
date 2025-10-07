#ifndef VERSIONHELPER_H
#define VERSIONHELPER_H

#include <QObject>
#include <qqml.h>

class VersionHelper : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    static VersionHelper* create(QQmlEngine *qmlEngine, QJSEngine *jsEngine);
    static VersionHelper* instance();

    Q_INVOKABLE QString getApplicationVersion();
    Q_INVOKABLE QString getQtVersion();
    Q_INVOKABLE QString getCommitSha();
    Q_INVOKABLE QString getBuildTimestamp();

private:
    explicit VersionHelper(QObject *parent = nullptr);
    static VersionHelper *s_instance;

};

#endif // VERSIONHELPER_H
