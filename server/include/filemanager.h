#ifndef FILEMANAGER_H
#define FILEMANAGER_H

#include <QString>
#include <QFileInfo>
#include <QJsonArray>
#include <QProcess>

class FileManager
{
public:
    FileManager(const QString &rootPath);

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

    QProcess* createZipFromDirectory(const QString &relativePath, const QString &zipName, QString& outZipPath);
    QProcess* createZipFromMultiplePaths(const QStringList &paths, const QString &zipName, QString& outZipPath);

private:
    QString m_rootPath;

    qint64 calculateDirectorySize(const QString &path) const;
};

#endif // FILEMANAGER_H
