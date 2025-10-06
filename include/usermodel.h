#ifndef USERMODEL_H
#define USERMODEL_H

#include <QAbstractListModel>
#include <QJsonObject>
#include <qqml.h>

struct UserItem {
    QString username;
    qint64 storageLimit;
    QString password;
    bool isAdmin;
};

class UserModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)

public:
    enum Roles {
        UsernameRole = Qt::UserRole + 1,
        StorageLimitRole,
        PasswordRole,
        IsAdminRole
    };

    static UserModel* create(QQmlEngine *qmlEngine, QJSEngine *jsEngine);
    static UserModel* instance();

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE void loadUsers(const QVariantList &users);
    Q_INVOKABLE void clear();
    Q_INVOKABLE int findUserIndex(const QString &username) const;

signals:
    void countChanged();

private:
    explicit UserModel(QObject *parent = nullptr);
    UserModel(const UserModel&) = delete;
    UserModel& operator=(const UserModel&) = delete;

    static UserModel *s_instance;

    QList<UserItem> m_users;
};

#endif // USERMODEL_H
