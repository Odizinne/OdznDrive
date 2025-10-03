#include "filemanager.h"
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonObject>
#include <QDateTime>

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

QJsonArray FileManager::listDirectory(const QString &relativePath)
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
    
    QFileInfoList entries = dir.entryInfoList(QDir::AllEntries | QDir::NoDotAndDotDot, QDir::Name);
    
    for (const QFileInfo &info : entries) {
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
    
    for (const QFileInfo &info : entries) {
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

    // If destination is a directory, move into it
    if (toInfo.isDir()) {
        QString fileName = fromInfo.fileName();
        absToPath = QDir(absToPath).filePath(fileName);
    }

    // Create parent directory if needed
    QDir().mkpath(QFileInfo(absToPath).absolutePath());

    return QFile::rename(absFromPath, absToPath);
}
