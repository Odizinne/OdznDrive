#include "versionhelper.h"
#include "version.h"
VersionHelper* VersionHelper::s_instance = nullptr;

VersionHelper::VersionHelper(QObject *parent)
    : QObject(parent)
{
}

VersionHelper* VersionHelper::create(QQmlEngine *qmlEngine, QJSEngine *jsEngine)
{
    Q_UNUSED(qmlEngine)
    Q_UNUSED(jsEngine)

    return instance();
}

VersionHelper* VersionHelper::instance()
{
    if (!s_instance) {
        s_instance = new VersionHelper();
    }
    return s_instance;
}

QString VersionHelper::getApplicationVersion()
{
    return APP_VERSION_STRING;
}

QString VersionHelper::getQtVersion()
{
    return QT_VERSION_STRING;
}

QString VersionHelper::getCommitSha()
{
    return GIT_COMMIT_HASH;
}

QString VersionHelper::getBuildTimestamp()
{
    return BUILD_TIMESTAMP;
}
