#include "filedialoghelper.h"
#include <QFileDialog>

FileDialogHelper* FileDialogHelper::s_instance = nullptr;

FileDialogHelper::FileDialogHelper(QObject *parent)
    : QObject(parent)
{
}

FileDialogHelper* FileDialogHelper::create(QQmlEngine *qmlEngine, QJSEngine *jsEngine)
{
    Q_UNUSED(qmlEngine)
    Q_UNUSED(jsEngine)

    return instance();
}

FileDialogHelper* FileDialogHelper::instance()
{
    if (!s_instance) {
        s_instance = new FileDialogHelper();
    }
    return s_instance;
}

QStringList FileDialogHelper::openFiles(const QString &title)
{
    QStringList files = QFileDialog::getOpenFileNames(
        nullptr,
        title,
        QString(),
        "All Files (*)"
        );

    return files;
}

QString FileDialogHelper::saveFile(const QString &title, const QString &defaultName, const QString &filter)
{
    QString filterStr = filter.isEmpty() ? "All Files (*)" : filter;

    QString file = QFileDialog::getSaveFileName(
        nullptr,
        title,
        defaultName,
        filterStr
        );

    return file;
}
