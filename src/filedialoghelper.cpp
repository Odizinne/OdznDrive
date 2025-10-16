// src/filedialoghelper.cpp
#include "filedialoghelper.h"
#include <QFileDialog>
#include <QStandardPaths>
#include <QFileInfo>
#include <QFile>
#include <QTextStream>
#include <QDateTime>

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

QString FileDialogHelper::openFolder(const QString &title)
{
    QString defaultDir = QStandardPaths::writableLocation(QStandardPaths::HomeLocation);

    QString folder = QFileDialog::getExistingDirectory(
        nullptr,
        title,
        defaultDir,
        QFileDialog::ShowDirsOnly | QFileDialog::DontResolveSymlinks
        );

    return folder;
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

bool FileDialogHelper::isDirectory(const QString &path)
{
    QFileInfo info(path);
    return info.exists() && info.isDir();
}

QString FileDialogHelper::getTempFilePath(const QString &fileName)
{
    QString tempDir = QDir::tempPath();
    QString uniqueName = QString("odz_preview_%1_%2").arg(QDateTime::currentMSecsSinceEpoch()).arg(fileName);
    return QDir(tempDir).filePath(uniqueName);
}

QString FileDialogHelper::readTextFile(const QString &filePath)
{
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qWarning() << "Failed to open file for reading:" << filePath;
        return QString();
    }

    QTextStream in(&file);
    in.setEncoding(QStringConverter::Utf8);
    QString content = in.readAll();
    file.close();
    return content;
}

bool FileDialogHelper::writeTextFile(const QString &filePath, const QString &content)
{
    QFile file(filePath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qWarning() << "Failed to open file for writing:" << filePath;
        return false;
    }

    QTextStream out(&file);
    out.setEncoding(QStringConverter::Utf8);
    out << content;
    file.close();
    return true;
}

bool FileDialogHelper::deleteFile(const QString &filePath)
{
    QFile file(filePath);
    if (file.exists()) {
        return file.remove();
    }
    return true; // Already deleted
}
