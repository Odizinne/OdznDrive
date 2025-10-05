#ifndef CONFIG_H
#define CONFIG_H

#include <QString>
#include <QSettings>
#include <QMap>
#include <QDateTime>

struct BannedIP {
    QString ip;
    QDateTime bannedUntil;
    int failedAttempts;
};

class Config
{
public:
    static Config& instance();

    void load();
    void save();

    int port() const { return m_port; }
    void setPort(int port) { m_port = port; }

    QString storageRoot() const { return m_storageRoot; }
    void setStorageRoot(const QString &path) { m_storageRoot = path; }

    qint64 storageLimit() const { return m_storageLimit; }
    void setStorageLimit(qint64 limit) { m_storageLimit = limit; }

    QString password() const { return m_password; }
    void setPassword(const QString &password) { m_password = password; }

    QString serverName() const { return m_serverName; }
    void setServerName(const QString &name) { m_serverName = name; }

    // Ban management
    bool isIPBanned(const QString &ip);
    void recordFailedAttempt(const QString &ip);
    void clearFailedAttempts(const QString &ip);
    void loadBannedIPs();
    void saveBannedIPs();

private:
    Config();
    Config(const Config&) = delete;
    Config& operator=(const Config&) = delete;

    int m_port;
    QString m_storageRoot;
    qint64 m_storageLimit;
    QString m_password;
    QString m_serverName;

    QSettings m_settings;
    QMap<QString, BannedIP> m_bannedIPs;
    QString getBannedIPsFilePath() const;
};

#endif // CONFIG_H
