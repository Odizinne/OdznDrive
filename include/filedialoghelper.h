#ifndef FILEDIALOGHELPER_H
#define FILEDIALOGHELPER_H

#include <QObject>
#include <QStringList>
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
    Q_INVOKABLE QString saveFile(const QString &title = "Save File",
                                 const QString &defaultName = "",
                                 const QString &filter = "");

private:
    explicit FileDialogHelper(QObject *parent = nullptr);
    FileDialogHelper(const FileDialogHelper&) = delete;
    FileDialogHelper& operator=(const FileDialogHelper&) = delete;

    static FileDialogHelper *s_instance;
};

#endif // FILEDIALOGHELPER_H
