#ifndef CONFIG_H
#define CONFIG_H

#include <QString>
#include <QSettings>
#include <QMap>
#include <QDateTime>
#include <QList>

struct BannedIP {
    QString ip;
    QDateTime bannedUntil;
    int failedAttempts;
};

struct User {
    QString username;
    QString password;
    QString storagePath;
    qint64 storageLimit;
    bool isAdmin;
};

class Config
{
public:
    static Config& instance();

    QString storageRoot() const { return m_storageRoot; }
    void setStorageRoot(const QString &path) { m_storageRoot = path; }

    bool isIPBanned(const QString &ip);
    void recordFailedAttempt(const QString &ip);
    void clearFailedAttempts(const QString &ip);
    void loadBannedIPs();
    void saveBannedIPs();

    QList<User> getUsers() const;
    User* getUser(const QString &username);
    bool createUser(const QString &username, const QString &password, const bool &isAdmin,
                    const qint64 &storageLimit, const QString &storagePath = QString());
    bool deleteUser(const QString &username);
    void loadUsers();
    void saveUsers();

    void initSettings();

private:
    Config();
    Config(const Config&) = delete;
    Config& operator=(const Config&) = delete;

    QString m_storageRoot;

    QSettings m_settings;
    QMap<QString, BannedIP> m_bannedIPs;
    QList<User> m_users;

    QString getBannedIPsFilePath() const;
    QString getUsersFilePath() const;
    QString generateUserStoragePath(const QString &username) const;
    static QString getDefaultLocalNetworkUrl();
};

#endif // CONFIG_H
