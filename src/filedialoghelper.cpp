#include "filedialoghelper.h"
#include <QFileDialog>
#include <QStandardPaths>

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
    QString defaultDir = QStandardPaths::writableLocation(QStandardPaths::HomeLocation);

    QStringList files = QFileDialog::getOpenFileNames(
        nullptr,
        title,
        defaultDir,
        "All Files (*)"
        );

    return files;
}

QString FileDialogHelper::saveFile(const QString &title, const QString &defaultName, const QString &filter)
{
    QString filterStr = filter.isEmpty() ? "All Files (*)" : filter;
    QString defaultDir = QStandardPaths::writableLocation(QStandardPaths::HomeLocation);
    QString initialPath = QDir(defaultDir).filePath(defaultName);

    QString file = QFileDialog::getSaveFileName(
        nullptr,
        title,
        initialPath,
        filterStr
        );

    return file;
}

QString FileDialogHelper::getExistingDirectory(const QString &title)
{
    QString defaultDir = QStandardPaths::writableLocation(QStandardPaths::HomeLocation);

    QString dir = QFileDialog::getExistingDirectory(
        nullptr,
        title,
        defaultDir
        );
    return dir;
}

void FileDialogHelper::ensureDirectoryExists(const QString &path)
{
    if (path.isEmpty()) {
        qDebug() << "ensureDirectoryExists: path is empty, doing nothing.";
        return;
    }

    QDir dir;
    if (!dir.mkpath(path)) {
        qDebug() << "Failed to create directory:" << path;
    }
}

QString FileDialogHelper::joinPath(const QString &basePath, const QString &fileName)
{
    if (basePath.isEmpty()) {
        return fileName;
    }
    if (fileName.isEmpty()) {
        return basePath;
    }

    QDir baseDir(basePath);
    return baseDir.filePath(fileName);
}
