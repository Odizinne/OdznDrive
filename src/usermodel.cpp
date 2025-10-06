#include "usermodel.h"
#include <QJsonObject>

UserModel* UserModel::s_instance = nullptr;

UserModel::UserModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

UserModel* UserModel::create(QQmlEngine *qmlEngine, QJSEngine *jsEngine)
{
    Q_UNUSED(qmlEngine)
    Q_UNUSED(jsEngine)

    return instance();
}

UserModel* UserModel::instance()
{
    if (!s_instance) {
        s_instance = new UserModel();
    }
    return s_instance;
}

int UserModel::rowCount(const QModelIndex &parent) const
{
    Q_UNUSED(parent)
    return m_users.count();
}

QVariant UserModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_users.count()) {
        return QVariant();
    }

    const UserItem &item = m_users.at(index.row());

    switch (role) {
    case UsernameRole:
        return item.username;
    case StorageLimitRole:
        return item.storageLimit;
    case PasswordRole:
        return item.password;
    case IsAdminRole:
        return item.isAdmin;
    default:
        return QVariant();
    }
}

QHash<int, QByteArray> UserModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[UsernameRole] = "username";
    roles[StorageLimitRole] = "storageLimit";
    roles[PasswordRole] = "password";
    roles[IsAdminRole] = "isAdmin";
    return roles;
}

void UserModel::loadUsers(const QVariantList &users)
{
    beginResetModel();

    m_users.clear();

    for (const QVariant &value : users) {
        QVariantMap obj = value.toMap();

        UserItem item;
        item.username = obj["username"].toString();
        item.storageLimit = obj["storageLimit"].toLongLong();
        item.password = obj["password"].toString();
        item.isAdmin = obj["isAdmin"].toBool();

        m_users.append(item);
    }

    endResetModel();

    emit countChanged();
}

void UserModel::clear()
{
    beginResetModel();
    m_users.clear();
    endResetModel();

    emit countChanged();
}

int UserModel::findUserIndex(const QString &username) const
{
    for (int i = 0; i < m_users.count(); ++i) {
        if (m_users[i].username == username) {
            return i;
        }
    }
    return -1;
}
