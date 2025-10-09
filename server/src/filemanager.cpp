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
    // Reject suspicious patterns immediately
    if (relativePath.contains("..") ||
        relativePath.contains("//") ||
        relativePath.startsWith("/") ||
        relativePath.contains('\\')) {
        qWarning() << "Suspicious path rejected:" << relativePath;
        return false;
    }

    QString absPath = getAbsolutePath(relativePath);
    QDir rootDir(m_rootPath);
    QString rootCanonical = rootDir.canonicalPath();
    QString canonical = QFileInfo(absPath).canonicalFilePath();

    // For new files that don't exist yet, validate parent directory
    if (canonical.isEmpty()) {
        QFileInfo parentInfo(QFileInfo(absPath).absolutePath());
        canonical = parentInfo.canonicalFilePath();

        // Still empty? Reject it!
        if (canonical.isEmpty()) {
            qWarning() << "Could not resolve canonical path for:" << relativePath;
            return false;
        }
    }

    bool isValid = canonical.startsWith(rootCanonical);
    if (!isValid) {
        qWarning() << "Path traversal attempt detected:" << relativePath;
        qWarning() << "Canonical:" << canonical;
        qWarning() << "Root:" << rootCanonical;
    }

    return isValid;
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

    QDir parentDir = info.dir();
    QString newAbsPath = parentDir.filePath(newName);

    if (QFileInfo::exists(newAbsPath)) {
        return false;
    }

    return QFile::rename(absPath, newAbsPath);
}

QProcess* FileManager::createZipFromDirectory(const QString &path, const QString &dirName, QString& outZipPath)
{
    if (!isValidPath(path)) {
        outZipPath.clear();
        return nullptr;
    }

    QString absPath = getAbsolutePath(path);
    QFileInfo dirInfo(absPath);

    if (!dirInfo.exists() || !dirInfo.isDir()) {
        outZipPath.clear();
        return nullptr;
    }

    QString tempDir = QDir::temp().filePath("odzndrive-" + QString::number(QCoreApplication::applicationPid()));
    QDir().mkpath(tempDir);

    QString zipFileName = dirName + ".zip";
    outZipPath = QDir(tempDir).filePath(zipFileName);
    QFile::remove(outZipPath);

    QProcess* process = new QProcess();

#ifdef Q_OS_WIN
    QString psCommand = QString(
                            "Compress-Archive -Path '%1\\*' -DestinationPath '%2' -CompressionLevel NoCompression -Force"
                            ).arg(absPath.replace("'", "''"), outZipPath.replace("'", "''"));

    process->start("powershell", {"-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", psCommand});
#else
    QStringList args;
    args << "-0" << "-r" << outZipPath << dirName;
    process->setWorkingDirectory(QFileInfo(absPath).absolutePath());
    process->start("zip", args);
#endif
    return process;
}


QProcess* FileManager::createZipFromMultiplePaths(const QStringList &paths, const QString &zipName, QString& outZipPath)
{
    if (paths.isEmpty()) {
        outZipPath.clear();
        return nullptr;
    }

    QString tempDir = QDir::temp().filePath("odzndrive-" + QString::number(QCoreApplication::applicationPid()));
    QDir().mkpath(tempDir);

    QString zipFileName = zipName + ".zip";
    outZipPath = QDir(tempDir).filePath(zipFileName);
    QFile::remove(outZipPath);

    QStringList validPaths;
    for (const QString &path : paths) {
        if (isValidPath(path)) {
            QString absPath = getAbsolutePath(path);
            if (QFileInfo::exists(absPath))
                validPaths << absPath;
        }
    }

    if (validPaths.isEmpty()) {
        outZipPath.clear();
        return nullptr;
    }

    QProcess* process = new QProcess();

#ifdef Q_OS_WIN
    QStringList quotedPaths;
    for (int i = 0; i < validPaths.size(); ++i) {
        QString escapedPath = validPaths.at(i);
        escapedPath.replace("'", "''");
        quotedPaths << QString("'%1'").arg(escapedPath);
    }

    QString escapedOutZip = outZipPath;
    escapedOutZip.replace("'", "''");

    QString psCommand = QString(
                            "Compress-Archive -Path %1 -DestinationPath '%2' -CompressionLevel NoCompression -Force"
                            ).arg(quotedPaths.join(","), escapedOutZip);

    process->start("powershell",
                   {"-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", psCommand});
#else
    QStringList args;
    args << "-0" << "-r" << outZipPath;
    args.append(validPaths);
    process->setWorkingDirectory(m_rootPath);
    process->start("zip", args);
#endif

    return process;
}

QJsonObject FileManager::getFolderTree(const QString &relativePath, int maxDepth)
{
    QJsonObject result;

    if (!isValidPath(relativePath)) {
        return result;
    }

    QString absPath = getAbsolutePath(relativePath);
    QFileInfo dirInfo(absPath);

    if (!dirInfo.exists() || !dirInfo.isDir()) {
        return result;
    }

    result["name"] = dirInfo.fileName().isEmpty() ? "Root" : dirInfo.fileName();
    result["path"] = relativePath;
    result["isDir"] = true;

    if (maxDepth == 0) {
        return result;
    }

    QDir dir(absPath);
    QFileInfoList entries = dir.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);

    QJsonArray children;
    for (const QFileInfo &info : std::as_const(entries)) {
        QString relPath = relativePath;
        if (!relPath.isEmpty() && !relPath.endsWith('/')) {
            relPath += '/';
        }
        relPath += info.fileName();

        QJsonObject child = getFolderTree(relPath, maxDepth - 1);
        children.append(child);
    }

    result["children"] = children;
    result["hasChildren"] = !children.isEmpty();

    return result;
}
