#ifndef FILEMANAGER_H
#define FILEMANAGER_H

#include <QString>
#include <QFileInfo>
#include <QJsonArray>
#include <QObject>
#include <QTextCodec>
#include <quazip/quazip.h>
#include <quazip/quazipfile.h>

class FileManager : public QObject
{
    Q_OBJECT

public:
    FileManager(const QString &rootPath, QObject *parent = nullptr);

    bool isValidPath(const QString &relativePath) const;
    QString getAbsolutePath(const QString &relativePath) const;

    QJsonArray listDirectory(const QString &relativePath, bool foldersFirst = true);
    bool createDirectory(const QString &relativePath);
    bool deleteFile(const QString &relativePath);
    bool deleteDirectory(const QString &relativePath);
    bool moveItem(const QString &fromPath, const QString &toPath);
    bool renameItem(const QString &path, const QString &newName);

    qint64 getTotalSize() const;
    qint64 getAvailableSpace(qint64 limit) const;

    bool saveFile(const QString &relativePath, const QByteArray &data);
    QByteArray readFile(const QString &relativePath);
    qint64 getFileSize(const QString &relativePath) const;

    // Synchronous versions (kept for compatibility)
    bool createZipFromDirectory(const QString &relativePath, const QString &zipPath, int compressionLevel = 0);
    bool createZipFromMultiplePaths(const QStringList &paths, const QString &zipPath, int compressionLevel = 0);

    // NEW: Asynchronous versions
    void createZipFromDirectoryAsync(const QString &relativePath, const QString &zipPath, int compressionLevel = 0);
    void createZipFromMultiplePathsAsync(const QStringList &paths, const QString &zipPath, int compressionLevel = 0);

    QJsonObject getFolderTree(const QString &relativePath, int maxDepth = -1);

signals:
    void zipCreationComplete(bool success, const QString &zipPath);

private:
    QString m_rootPath;
    qint64 calculateDirectorySize(const QString &path) const;

    bool addDirectoryToZip(QuaZip &zip, const QString &dirPath, const QString &baseDir, int compressionLevel);
    bool addFileToZip(QuaZip &zip, const QString &filePath, const QString &zipPath, int compressionLevel);
};

#endif // FILEMANAGER_H
