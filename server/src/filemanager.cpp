#include "filemanager.h"
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonObject>
#include <QDateTime>
#include <QDirIterator>
#include <QStorageInfo>

FileManager::FileManager(const QString &rootPath, QObject *parent)
    : QObject(parent)
    , m_rootPath(QDir(rootPath).absolutePath())
{
    QDir().mkpath(m_rootPath);
}

bool FileManager::isValidPath(const QString &relativePath) const
{
    if (relativePath.isEmpty()) {
        return true;
    }

    QString absPath = getAbsolutePath(relativePath);
    QString canonicalPath = QFileInfo(absPath).canonicalFilePath();

    if (canonicalPath.isEmpty()) {
        canonicalPath = QDir(absPath).absolutePath();
    }

    return canonicalPath.startsWith(m_rootPath);
}

QString FileManager::getAbsolutePath(const QString &relativePath) const
{
    if (relativePath.isEmpty()) {
        return m_rootPath;
    }

    QString cleanPath = relativePath;
    while (cleanPath.startsWith('/')) {
        cleanPath = cleanPath.mid(1);
    }

    return QDir(m_rootPath).filePath(cleanPath);
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

    QFileInfoList entries = dir.entryInfoList(QDir::AllEntries | QDir::NoDotAndDotDot);

    if (foldersFirst) {
        std::sort(entries.begin(), entries.end(), [](const QFileInfo &a, const QFileInfo &b) {
            if (a.isDir() != b.isDir()) {
                return a.isDir();
            }
            return a.fileName().toLower() < b.fileName().toLower();
        });
    }

    for (const QFileInfo &entry : std::as_const(entries)) {
        QJsonObject item;
        item["name"] = entry.fileName();
        item["isDirectory"] = entry.isDir();
        item["size"] = entry.size();
        item["modified"] = entry.lastModified().toString(Qt::ISODate);

        result.append(item);
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

    if (!dir.exists()) {
        return false;
    }

    return dir.removeRecursively();
}

bool FileManager::moveItem(const QString &fromPath, const QString &toPath)
{
    if (!isValidPath(fromPath) || !isValidPath(toPath)) {
        return false;
    }

    QString absFrom = getAbsolutePath(fromPath);
    QString absTo = getAbsolutePath(toPath);

    QFileInfo fromInfo(absFrom);
    if (!fromInfo.exists()) {
        return false;
    }

    QFileInfo toInfo(absTo);
    if (toInfo.exists()) {
        return false;
    }

    QString toDir = toInfo.absolutePath();
    QDir().mkpath(toDir);

    return QFile::rename(absFrom, absTo);
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

    QString newPath = info.absolutePath() + "/" + newName;
    return QFile::rename(absPath, newPath);
}

qint64 FileManager::calculateDirectorySize(const QString &path) const
{
    qint64 size = 0;
    QDirIterator it(path, QDir::Files | QDir::NoDotAndDotDot, QDirIterator::Subdirectories);

    while (it.hasNext()) {
        it.next();
        size += it.fileInfo().size();
    }

    return size;
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

    qint64 written = file.write(data);
    file.close();

    return written == data.size();
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

qint64 FileManager::getFileSize(const QString &relativePath) const
{
    if (!isValidPath(relativePath)) {
        return 0;
    }

    QString absPath = getAbsolutePath(relativePath);
    return QFileInfo(absPath).size();
}

QJsonObject FileManager::getFolderTree(const QString &relativePath, int maxDepth)
{
    QJsonObject tree;

    if (!isValidPath(relativePath)) {
        return tree;
    }

    QString absPath = getAbsolutePath(relativePath);
    QFileInfo rootInfo(absPath);

    if (!rootInfo.exists() || !rootInfo.isDir()) {
        return tree;
    }

    tree["name"] = rootInfo.fileName().isEmpty() ? "root" : rootInfo.fileName();
    tree["isDirectory"] = true;
    tree["path"] = relativePath;

    if (maxDepth == 0) {
        return tree;
    }

    QJsonArray children;
    QDir dir(absPath);
    QFileInfoList entries = dir.entryInfoList(QDir::AllEntries | QDir::NoDotAndDotDot);

    for (const QFileInfo &entry : std::as_const(entries)) {
        QJsonObject child;
        QString childRelPath = relativePath.isEmpty()
                                   ? entry.fileName()
                                   : relativePath + "/" + entry.fileName();

        child["name"] = entry.fileName();
        child["isDirectory"] = entry.isDir();
        child["path"] = childRelPath;

        if (entry.isDir() && maxDepth != 1) {
            QJsonObject subTree = getFolderTree(childRelPath, maxDepth > 0 ? maxDepth - 1 : -1);
            if (subTree.contains("children")) {
                child["children"] = subTree["children"];
            }
        }

        children.append(child);
    }

    tree["children"] = children;
    return tree;
}

bool FileManager::addFileToZip(QuaZip &zip, const QString &filePath, const QString &zipPath, int compressionLevel)
{
    QFile inFile(filePath);
    if (!inFile.open(QIODevice::ReadOnly)) {
        qWarning() << "Failed to open file for zipping:" << filePath;
        return false;
    }

    QuaZipFile outFile(&zip);
    QuaZipNewInfo info(zipPath, filePath);
    info.setPermissions(QFile::permissions(filePath));

    // Use specified compression level (0-9)
    // method = Z_DEFLATED, level = compressionLevel
    if (!outFile.open(QIODevice::WriteOnly, info, nullptr, 0, Z_DEFLATED, compressionLevel)) {
        qWarning() << "Failed to create zip entry:" << zipPath;
        inFile.close();
        return false;
    }

    // Read and write in chunks to avoid memory issues
    const qint64 chunkSize = 1024 * 1024; // 1MB chunks
    while (!inFile.atEnd()) {
        QByteArray chunk = inFile.read(chunkSize);
        if (chunk.isEmpty() && !inFile.atEnd()) {
            qWarning() << "Failed to read from file:" << filePath;
            outFile.close();
            inFile.close();
            return false;
        }

        if (outFile.write(chunk) != chunk.size()) {
            qWarning() << "Failed to write to zip:" << zipPath;
            outFile.close();
            inFile.close();
            return false;
        }
    }

    outFile.close();
    inFile.close();

    return outFile.getZipError() == UNZ_OK;
}

bool FileManager::addDirectoryToZip(QuaZip &zip, const QString &dirPath, const QString &baseDir, int compressionLevel)
{
    QDir dir(dirPath);
    if (!dir.exists()) {
        qWarning() << "Directory does not exist:" << dirPath;
        return false;
    }

    QFileInfoList entries = dir.entryInfoList(QDir::AllEntries | QDir::NoDotAndDotDot);

    for (const QFileInfo &entry : entries) {
        QString relativePath = entry.absoluteFilePath().mid(baseDir.length());
        if (relativePath.startsWith('/') || relativePath.startsWith('\\')) {
            relativePath = relativePath.mid(1);
        }

        if (entry.isDir()) {
            // Recursively add subdirectory
            if (!addDirectoryToZip(zip, entry.absoluteFilePath(), baseDir, compressionLevel)) {
                return false;
            }
        } else {
            // Add file
            if (!addFileToZip(zip, entry.absoluteFilePath(), relativePath, compressionLevel)) {
                return false;
            }
        }
    }

    return true;
}

bool FileManager::createZipFromDirectory(const QString &relativePath, const QString &zipPath, int compressionLevel)
{
    if (!isValidPath(relativePath)) {
        qWarning() << "Invalid path for zipping:" << relativePath;
        return false;
    }

    QString absPath = getAbsolutePath(relativePath);
    QFileInfo dirInfo(absPath);

    if (!dirInfo.exists() || !dirInfo.isDir()) {
        qWarning() << "Directory not found:" << absPath;
        return false;
    }

    // Remove existing zip file
    QFile::remove(zipPath);

    // Create zip file
    QuaZip zip(zipPath);
    if (!zip.open(QuaZip::mdCreate)) {
        qWarning() << "Failed to create zip file:" << zipPath;
        return false;
    }

    // Add directory contents to zip with specified compression level
    bool success = addDirectoryToZip(zip, absPath, dirInfo.absolutePath(), compressionLevel);

    zip.close();

    if (!success || zip.getZipError() != UNZ_OK) {
        qWarning() << "Zip creation failed with error:" << zip.getZipError();
        QFile::remove(zipPath);
        return false;
    }

    qInfo() << "Successfully created zip:" << zipPath << "with compression level:" << compressionLevel;
    return true;
}

bool FileManager::createZipFromMultiplePaths(const QStringList &paths, const QString &zipPath, int compressionLevel)
{
    if (paths.isEmpty()) {
        qWarning() << "No paths provided for zipping";
        return false;
    }

    QFile::remove(zipPath);

    QuaZip zip(zipPath);
    if (!zip.open(QuaZip::mdCreate)) {
        qWarning() << "Failed to create zip file:" << zipPath;
        return false;
    }

    bool success = true;

    for (const QString &path : paths) {
        if (!isValidPath(path)) {
            qWarning() << "Skipping invalid path:" << path;
            continue;
        }

        QString absPath = getAbsolutePath(path);
        QFileInfo info(absPath);

        if (!info.exists()) {
            qWarning() << "Path not found:" << absPath;
            continue;
        }

        if (info.isDir()) {
            if (!addDirectoryToZip(zip, absPath, m_rootPath, compressionLevel)) {
                success = false;
                break;
            }
        } else {
            QString relativePath = path;
            if (!addFileToZip(zip, absPath, relativePath, compressionLevel)) {
                success = false;
                break;
            }
        }
    }

    zip.close();

    if (!success || zip.getZipError() != UNZ_OK) {
        qWarning() << "Zip creation failed with error:" << zip.getZipError();
        QFile::remove(zipPath);
        return false;
    }

    qInfo() << "Successfully created zip:" << zipPath << "with compression level:" << compressionLevel;
    return true;
}
