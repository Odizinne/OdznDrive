#include "filemodel.h"
#include <QJsonObject>

FileModel* FileModel::s_instance = nullptr;

FileModel::FileModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

FileModel* FileModel::create(QQmlEngine *qmlEngine, QJSEngine *jsEngine)
{
    Q_UNUSED(qmlEngine)
    Q_UNUSED(jsEngine)
    
    return instance();
}

FileModel* FileModel::instance()
{
    if (!s_instance) {
        s_instance = new FileModel();
    }
    return s_instance;
}

int FileModel::rowCount(const QModelIndex &parent) const
{
    Q_UNUSED(parent)
    return m_files.count();
}

QVariant FileModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_files.count()) {
        return QVariant();
    }
    
    const FileItem &item = m_files.at(index.row());
    
    switch (role) {
    case NameRole:
        return item.name;
    case PathRole:
        return item.path;
    case IsDirRole:
        return item.isDir;
    case SizeRole:
        return item.size;
    case ModifiedRole:
        return item.modified;
    default:
        return QVariant();
    }
}

QHash<int, QByteArray> FileModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[NameRole] = "name";
    roles[PathRole] = "path";
    roles[IsDirRole] = "isDir";
    roles[SizeRole] = "size";
    roles[ModifiedRole] = "modified";
    return roles;
}

void FileModel::loadDirectory(const QString &path, const QVariantList &files)
{
    beginResetModel();

    m_files.clear();
    m_currentPath = path;

    for (const QVariant &value : files) {
        QVariantMap obj = value.toMap();

        FileItem item;
        item.name = obj["name"].toString();
        item.path = obj["path"].toString();
        item.isDir = obj["isDir"].toBool();
        item.size = obj["size"].toLongLong();
        item.modified = obj["modified"].toString();

        m_files.append(item);
    }

    endResetModel();

    emit currentPathChanged();
    emit countChanged();
}

void FileModel::clear()
{
    beginResetModel();
    m_files.clear();
    m_currentPath.clear();
    endResetModel();
    
    emit currentPathChanged();
    emit countChanged();
}

QString FileModel::getParentPath() const
{
    if (m_currentPath.isEmpty() || m_currentPath == "/") {
        return QString();
    }
    
    int lastSlash = m_currentPath.lastIndexOf('/');
    if (lastSlash <= 0) {
        return QString();
    }
    
    return m_currentPath.left(lastSlash);
}

bool FileModel::canGoUp() const
{
    return !m_currentPath.isEmpty() && m_currentPath != "/";
}
