#include "filemanager.h"
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonObject>
#include <QDateTime>
#include <QProcess>
#include <QCoreApplication>

FileManager::FileManager(const QString &rootPath)
    : m_rootPath(QDir(rootPath).absolutePath())
{
    QDir().mkpath(m_rootPath);
}

bool FileManager::isValidPath(const QString &relativePath) const
{
    QString absPath = getAbsolutePath(relativePath);
    QDir rootDir(m_rootPath);
    QString canonical = QFileInfo(absPath).canonicalFilePath();

    if (canonical.isEmpty()) {
        canonical = QFileInfo(absPath).absoluteFilePath();
    }

    return canonical.startsWith(rootDir.canonicalPath());
}

QString FileManager::getAbsolutePath(const QString &relativePath) const
{
    QDir rootDir(m_rootPath);
    return rootDir.absoluteFilePath(relativePath);
}

QJsonArray FileManager::listDirectory(const QString &relativePath, bool foldersFirst)
{
    QJsonArray result;

    if (!isValidPath(relativePath)) {
        return result;
    }

    QString absPath = getAbsolutePath(relativePath);
    QDir dir(absPath);

    if (!dir.exists()) {
        return result;
    }

    QFileInfoList entries = dir.entryInfoList(QDir::AllEntries | QDir::NoDotAndDotDot, QDir::NoSort);

    auto caseInsensitiveCompare = [foldersFirst](const QFileInfo &a, const QFileInfo &b) {
        if (foldersFirst) {
            if (a.isDir() && !b.isDir()) {
                return true;
            }
            if (!a.isDir() && b.isDir()) {
                return false;
            }
        }
        return a.fileName().compare(b.fileName(), Qt::CaseInsensitive) < 0;
    };

    std::sort(entries.begin(), entries.end(), caseInsensitiveCompare);

    for (const QFileInfo &info : std::as_const(entries)) {
        QJsonObject obj;
        obj["name"] = info.fileName();
        obj["isDir"] = info.isDir();
        obj["size"] = info.size();
        obj["modified"] = info.lastModified().toString(Qt::ISODate);

        QString relPath = relativePath;
        if (!relPath.isEmpty() && !relPath.endsWith('/')) {
            relPath += '/';
        }
        relPath += info.fileName();
        obj["path"] = relPath;

        result.append(obj);
    }

    return result;
}

bool FileManager::createDirectory(const QString &relativePath)
{
    if (!isValidPath(relativePath)) {
        return false;
    }

    QString absPath = getAbsolutePath(relativePath);
    return QDir().mkpath(absPath);
}

bool FileManager::deleteFile(const QString &relativePath)
{
    if (!isValidPath(relativePath)) {
        return false;
    }

    QString absPath = getAbsolutePath(relativePath);
    return QFile::remove(absPath);
}

bool FileManager::deleteDirectory(const QString &relativePath)
{
    if (!isValidPath(relativePath)) {
        return false;
    }

    QString absPath = getAbsolutePath(relativePath);
    QDir dir(absPath);
    return dir.removeRecursively();
}

qint64 FileManager::getTotalSize() const
{
    return calculateDirectorySize(m_rootPath);
}

qint64 FileManager::getAvailableSpace(qint64 limit) const
{
    qint64 used = getTotalSize();
    return limit - used;
}

bool FileManager::saveFile(const QString &relativePath, const QByteArray &data)
{
    if (!isValidPath(relativePath)) {
        return false;
    }

    QString absPath = getAbsolutePath(relativePath);
    QFileInfo fileInfo(absPath);

    QDir().mkpath(fileInfo.absolutePath());

    QFile file(absPath);
    if (!file.open(QIODevice::WriteOnly)) {
        return false;
    }

    return file.write(data) == data.size();
}

QByteArray FileManager::readFile(const QString &relativePath)
{
    if (!isValidPath(relativePath)) {
        return QByteArray();
    }

    QString absPath = getAbsolutePath(relativePath);
    QFile file(absPath);

    if (!file.open(QIODevice::ReadOnly)) {
        return QByteArray();
    }

    return file.readAll();
}

qint64 FileManager::calculateDirectorySize(const QString &path) const
{
    qint64 size = 0;
    QDir dir(path);

    QFileInfoList entries = dir.entryInfoList(QDir::AllEntries | QDir::NoDotAndDotDot);

    for (const QFileInfo &info : std::as_const(entries)) {
        if (info.isDir()) {
            size += calculateDirectorySize(info.absoluteFilePath());
        } else {
            size += info.size();
        }
    }

    return size;
}

bool FileManager::moveItem(const QString &fromPath, const QString &toPath)
{
    if (!isValidPath(fromPath) || !isValidPath(toPath)) {
        return false;
    }

    QString absFromPath = getAbsolutePath(fromPath);
    QString absToPath = getAbsolutePath(toPath);

    QFileInfo fromInfo(absFromPath);
    QFileInfo toInfo(absToPath);

    if (!fromInfo.exists()) {
        return false;
    }

    if (toInfo.isDir()) {
        QString fileName = fromInfo.fileName();
        absToPath = QDir(absToPath).filePath(fileName);
    }

    QDir().mkpath(QFileInfo(absToPath).absolutePath());

    return QFile::rename(absFromPath, absToPath);
}

qint64 FileManager::getFileSize(const QString &relativePath) const
{
    if (!isValidPath(relativePath)) {
        return 0;
    }

    QString absPath = getAbsolutePath(relativePath);
    QFileInfo info(absPath);

    if (info.isDir()) {
        return calculateDirectorySize(absPath);
    }

    return info.size();
}

QString FileManager::createZipFromDirectory(const QString &relativePath, const QString &zipName)
{
    if (!isValidPath(relativePath)) {
        return QString();
    }

    QString absSourcePath = getAbsolutePath(relativePath);
    QFileInfo sourceInfo(absSourcePath);

    if (!sourceInfo.exists() || !sourceInfo.isDir()) {
        return QString();
    }

    // Create temp directory for zip files
    QString tempDir = QDir(m_rootPath).filePath(".temp");
    QDir().mkpath(tempDir);

    QString zipFileName = zipName + ".zip";
    QString zipPath = QDir(tempDir).filePath(zipFileName);

    // Remove existing zip if any
    QFile::remove(zipPath);

    // Use system zip command
    QProcess process;
    process.setWorkingDirectory(absSourcePath);

    QStringList args;
    args << "-r" << zipPath << ".";

    process.start("zip", args);

    if (!process.waitForFinished(300000)) { // 5 minutes timeout
        return QString();
    }

    if (process.exitCode() != 0) {
        return QString();
    }

    // Return relative path to the zip file
    return ".temp/" + zipFileName;
}

QString FileManager::createZipFromMultiplePaths(const QStringList &paths, const QString &zipName)
{
    if (paths.isEmpty()) {
        return QString();
    }

    // --- CRITICAL FIX: Use a system temp directory OUTSIDE the user's storage root ---
    // This prevents the zip command from trying to zip itself.
    QString tempDir = QDir::temp().filePath("odzndrive-" + QString::number(QCoreApplication::applicationPid()));
    QDir().mkpath(tempDir);

    QString zipFileName = zipName + ".zip";
    QString zipPath = QDir(tempDir).filePath(zipFileName);

    // Remove existing zip if any
    QFile::remove(zipPath);

    // Prepare arguments for zip command using RELATIVE paths
    QStringList args;
    args << "-r" << zipPath;

    // Add all paths as relative paths
    for (const QString &path : paths) {
        if (!isValidPath(path)) {
            continue;
        }

        QString absPath = getAbsolutePath(path);
        if (QFileInfo::exists(absPath)) {
            args << path;
        }
    }

    if (args.size() <= 2) { // Only zipPath and -r
        QDir().rmdir(tempDir); // Clean up empty temp dir
        return QString();
    }

    QProcess process;
    process.setWorkingDirectory(m_rootPath);
    process.start("zip", args);

    // Use a shorter timeout to prevent the server from hanging indefinitely
    if (!process.waitForFinished(60000)) { // 60-second timeout
        qWarning() << "Zip process timed out or failed:" << process.errorString();
        QFile::remove(zipPath);
        QDir().rmdir(tempDir);
        return QString();
    }

    if (process.exitCode() != 0) {
        qWarning() << "Zip process exited with code" << process.exitCode();
        QFile::remove(zipPath);
        QDir().rmdir(tempDir);
        return QString();
    }

    // Return the absolute path to the file in the system temp directory
    return zipPath;
}

bool FileManager::renameItem(const QString &path, const QString &newName)
{
    if (!isValidPath(path)) {
        return false;
    }

    QString absPath = getAbsolutePath(path);
    QFileInfo info(absPath);

    if (!info.exists()) {
        return false;
    }

    // Get parent directory
    QDir parentDir = info.dir();
    QString newAbsPath = parentDir.filePath(newName);

    // Check if target already exists
    if (QFileInfo::exists(newAbsPath)) {
        return false;
    }

    return QFile::rename(absPath, newAbsPath);
}
