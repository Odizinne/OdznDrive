#ifndef FILEMANAGER_H
#define FILEMANAGER_H

#include <QString>
#include <QFileInfo>
#include <QJsonArray>

class FileManager
{
public:
    FileManager(const QString &rootPath);
    
    bool isValidPath(const QString &relativePath) const;
    QString getAbsolutePath(const QString &relativePath) const;
    
    QJsonArray listDirectory(const QString &relativePath);
    bool createDirectory(const QString &relativePath);
    bool deleteFile(const QString &relativePath);
    bool deleteDirectory(const QString &relativePath);
    bool moveItem(const QString &fromPath, const QString &toPath);  // Add this
    
    qint64 getTotalSize() const;
    qint64 getAvailableSpace(qint64 limit) const;
    
    bool saveFile(const QString &relativePath, const QByteArray &data);
    QByteArray readFile(const QString &relativePath);

private:
    QString m_rootPath;
    
    qint64 calculateDirectorySize(const QString &path) const;
};

#endif // FILEMANAGER_H
