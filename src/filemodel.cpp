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
    case PreviewPathRole:
        return item.previewPath;
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
    roles[PreviewPathRole] = "previewPath";
    return roles;
}

bool FileModel::isImageFile(const QString &fileName) const
{
    static const QStringList imageExtensions = {
        ".jpg", ".jpeg", ".png", ".gif", ".bmp", ".webp"
    };

    QString lower = fileName.toLower();
    for (const QString &ext : imageExtensions) {
        if (lower.endsWith(ext)) {
            return true;
        }
    }
    return false;
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

        // Check if thumbnail already exists in cache
        if (!item.isDir && isImageFile(item.name)) {
            // Will be set by ConnectionManager if thumbnail exists in cache
            item.previewPath = "";
        } else {
            item.previewPath = "";
        }

        m_files.append(item);
    }

    endResetModel();

    emit currentPathChanged();
    emit countChanged();
}

void FileModel::refreshThumbnail(const QString &path)
{
    for (int i = 0; i < m_files.count(); ++i) {
        if (m_files[i].path == path) {
            // NOW set the preview path when thumbnail is ready
            m_files[i].previewPath = "image://preview/" + path;
            QModelIndex idx = index(i, 0);
            emit dataChanged(idx, idx, {PreviewPathRole});
            break;
        }
    }
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

    if (lastSlash < 0) {
        return QString("");
    }

    if (lastSlash == 0) {
        return QString("");
    }

    return m_currentPath.left(lastSlash);
}

bool FileModel::canGoUp() const
{
    return !m_currentPath.isEmpty() && m_currentPath != "/";
}

