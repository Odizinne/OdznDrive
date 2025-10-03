#ifndef FILEMODEL_H
#define FILEMODEL_H

#include <QAbstractListModel>
#include <QJsonArray>
#include <qqml.h>

struct FileItem {
    QString name;
    QString path;
    bool isDir;
    qint64 size;
    QString modified;
};

class FileModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    
    Q_PROPERTY(QString currentPath READ currentPath NOTIFY currentPathChanged)
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    Q_PROPERTY(bool canGoUp READ canGoUp NOTIFY currentPathChanged)

public:
    enum Roles {
        NameRole = Qt::UserRole + 1,
        PathRole,
        IsDirRole,
        SizeRole,
        ModifiedRole
    };
    
    static FileModel* create(QQmlEngine *qmlEngine, QJSEngine *jsEngine);
    static FileModel* instance();
    
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;
    
    QString currentPath() const { return m_currentPath; }
    
    Q_INVOKABLE void loadDirectory(const QString &path, const QVariantList &files);
    Q_INVOKABLE void clear();
    Q_INVOKABLE QString getParentPath() const;
    Q_INVOKABLE bool canGoUp() const;

signals:
    void currentPathChanged();
    void countChanged();

private:
    explicit FileModel(QObject *parent = nullptr);
    FileModel(const FileModel&) = delete;
    FileModel& operator=(const FileModel&) = delete;
    
    static FileModel *s_instance;
    
    QList<FileItem> m_files;
    QString m_currentPath;
};

#endif // FILEMODEL_H
