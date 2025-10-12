// include/filedialoghelper.h
#ifndef FILEDIALOGHELPER_H
#define FILEDIALOGHELPER_H

#include <QObject>
#include <QStringList>
#include <QDir>
#include <qqml.h>

class FileDialogHelper : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    static FileDialogHelper* create(QQmlEngine *qmlEngine, QJSEngine *jsEngine);
    static FileDialogHelper* instance();

    Q_INVOKABLE QStringList openFiles(const QString &title = "Select Files");
    Q_INVOKABLE QString openFolder(const QString &title = "Select Folder");  // NEW
    Q_INVOKABLE QString saveFile(const QString &title = "Save File",
                                 const QString &defaultName = "",
                                 const QString &filter = "");
    Q_INVOKABLE QString getExistingDirectory(const QString &title = "Select Directory");
    Q_INVOKABLE void ensureDirectoryExists(const QString &path);
    Q_INVOKABLE QString joinPath(const QString &basePath, const QString &fileName);
    Q_INVOKABLE bool isDirectory(const QString &path);  // NEW

private:
    explicit FileDialogHelper(QObject *parent = nullptr);
    FileDialogHelper(const FileDialogHelper&) = delete;
    FileDialogHelper& operator=(const FileDialogHelper&) = delete;

    static FileDialogHelper *s_instance;
};

#endif // FILEDIALOGHELPER_H
