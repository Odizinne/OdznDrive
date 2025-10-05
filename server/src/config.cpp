#include "config.h"
#include <QDir>
#include <QStandardPaths>
#include <QCoreApplication>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QFile>

Config::Config()
    : m_settings(QCoreApplication::organizationName(), QCoreApplication::applicationName())
{
}

Config& Config::instance()
{
    static Config instance;
    return instance;
}

void Config::load()
{
    m_port = m_settings.value("server/port", 8888).toInt();

    QString defaultStorage = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/storage";
    m_storageRoot = m_settings.value("server/storage_root", defaultStorage).toString();

    m_storageLimit = m_settings.value("server/storage_limit", 10737418240LL).toLongLong(); // 10GB default
    m_password = m_settings.value("server/password", "admin123").toString();
    m_serverName = m_settings.value("server/name", "OdznDrive Server").toString();

    QDir().mkpath(m_storageRoot);
    loadBannedIPs();
    loadUsers();
}

void Config::save()
{
    m_settings.setValue("server/port", m_port);
    m_settings.setValue("server/storage_root", m_storageRoot);
    m_settings.setValue("server/storage_limit", m_storageLimit);
    m_settings.setValue("server/password", m_password);
    m_settings.setValue("server/name", m_serverName);
    m_settings.sync();
}

QString Config::getBannedIPsFilePath() const
{
    QString configPath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(configPath);
    return configPath + "/banned-ips.json";
}

QString Config::getUsersFilePath() const
{
    QString configPath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(configPath);
    return configPath + "/users.json";
}

QString Config::generateUserStoragePath(const QString &username) const
{
    // Use lowercase for filesystem to avoid case-sensitivity issues
    return QDir(m_storageRoot).filePath(username.toLower());
}

void Config::loadBannedIPs()
{
    QString filePath = getBannedIPsFilePath();
    QFile file(filePath);

    if (!file.exists()) {
        return;
    }

    if (!file.open(QIODevice::ReadOnly)) {
        qWarning() << "Failed to open banned IPs file:" << filePath;
        return;
    }

    QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    file.close();

    if (!doc.isArray()) {
        return;
    }

    QJsonArray array = doc.array();
    QDateTime now = QDateTime::currentDateTime();

    for (const QJsonValue &value : array) {
        QJsonObject obj = value.toObject();
        QString ip = obj["ip"].toString();
        QDateTime bannedUntil = QDateTime::fromString(obj["bannedUntil"].toString(), Qt::ISODate);
        int failedAttempts = obj["failedAttempts"].toInt();

        // Only load if ban is still active
        if (bannedUntil > now) {
            BannedIP banned;
            banned.ip = ip;
            banned.bannedUntil = bannedUntil;
            banned.failedAttempts = failedAttempts;
            m_bannedIPs[ip] = banned;
        }
    }
}

void Config::saveBannedIPs()
{
    QString filePath = getBannedIPsFilePath();
    QFile file(filePath);

    if (!file.open(QIODevice::WriteOnly)) {
        qWarning() << "Failed to save banned IPs file:" << filePath;
        return;
    }

    QJsonArray array;
    QDateTime now = QDateTime::currentDateTime();

    // Only save active bans
    for (auto it = m_bannedIPs.begin(); it != m_bannedIPs.end(); ) {
        if (it->bannedUntil > now) {
            QJsonObject obj;
            obj["ip"] = it->ip;
            obj["bannedUntil"] = it->bannedUntil.toString(Qt::ISODate);
            obj["failedAttempts"] = it->failedAttempts;
            array.append(obj);
            ++it;
        } else {
            it = m_bannedIPs.erase(it);
        }
    }

    QJsonDocument doc(array);
    file.write(doc.toJson());
    file.close();
}

bool Config::isIPBanned(const QString &ip)
{
    if (!m_bannedIPs.contains(ip)) {
        return false;
    }

    QDateTime now = QDateTime::currentDateTime();
    BannedIP &banned = m_bannedIPs[ip];

    if (banned.bannedUntil <= now) {
        // Ban expired, remove from list
        m_bannedIPs.remove(ip);
        saveBannedIPs();
        return false;
    }

    return true;
}

void Config::recordFailedAttempt(const QString &ip)
{
    QDateTime now = QDateTime::currentDateTime();

    if (!m_bannedIPs.contains(ip)) {
        BannedIP banned;
        banned.ip = ip;
        banned.failedAttempts = 1;
        banned.bannedUntil = now;
        m_bannedIPs[ip] = banned;
    } else {
        m_bannedIPs[ip].failedAttempts++;
    }

    // Ban for 30 minutes after 5 failed attempts
    if (m_bannedIPs[ip].failedAttempts >= 5) {
        m_bannedIPs[ip].bannedUntil = now.addSecs(30 * 60); // 30 minutes
        qWarning() << "IP banned for 30 minutes:" << ip << "(" << m_bannedIPs[ip].failedAttempts << "failed attempts)";
        saveBannedIPs();
    }
}

void Config::clearFailedAttempts(const QString &ip)
{
    if (m_bannedIPs.contains(ip)) {
        m_bannedIPs.remove(ip);
        saveBannedIPs();
    }
}

void Config::loadUsers()
{
    QString filePath = getUsersFilePath();
    QFile file(filePath);

    if (!file.exists()) {
        // Create default admin user
        User admin;
        admin.username = "admin";
        admin.password = "admin123";
        admin.storagePath = generateUserStoragePath("admin");
        admin.storageLimit = 10737418240LL; // 10GB
        m_users.append(admin);
        saveUsers();
        qInfo() << "Created default admin user";
        qInfo() << "Username: admin";
        qInfo() << "Password: admin123";
        qInfo() << "Storage path:" << admin.storagePath;
        return;
    }

    if (!file.open(QIODevice::ReadOnly)) {
        qWarning() << "Failed to load users file:" << filePath;
        return;
    }

    QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    file.close();

    if (!doc.isObject()) {
        qWarning() << "Invalid users file format";
        return;
    }

    QJsonArray usersArray = doc.object()["users"].toArray();
    for (const QJsonValue &val : usersArray) {
        QJsonObject obj = val.toObject();
        User user;
        user.username = obj["username"].toString();
        user.password = obj["password"].toString();
        user.storagePath = obj["storagePath"].toString();
        user.storageLimit = obj["storageLimit"].toVariant().toLongLong();
        m_users.append(user);

        // Ensure storage directory exists
        QDir().mkpath(user.storagePath);
    }

    qInfo() << "Loaded" << m_users.size() << "user(s)";
}

void Config::saveUsers()
{
    QString filePath = getUsersFilePath();
    QFile file(filePath);

    if (!file.open(QIODevice::WriteOnly)) {
        qWarning() << "Failed to save users file:" << filePath;
        return;
    }

    QJsonArray usersArray;
    for (const User &user : m_users) {
        QJsonObject obj;
        obj["username"] = user.username;
        obj["password"] = user.password;
        obj["storagePath"] = user.storagePath;
        obj["storageLimit"] = user.storageLimit;
        usersArray.append(obj);
    }

    QJsonObject root;
    root["users"] = usersArray;

    file.write(QJsonDocument(root).toJson());
    file.close();
}

User* Config::getUser(const QString &username)
{
    // Case-insensitive username lookup
    QString lowerUsername = username.toLower();

    for (User &user : m_users) {
        if (user.username.toLower() == lowerUsername) {
            return &user;
        }
    }
    return nullptr;
}

bool Config::createUser(const QString &username, const QString &password,
                        qint64 storageLimit, const QString &storagePath)
{
    // Check for existing user (case-insensitive)
    if (getUser(username)) {
        qWarning() << "User already exists:" << username << "(case-insensitive check)";
        return false;
    }

    User user;
    user.username = username; // Store original case for display
    user.password = password;
    user.storageLimit = storageLimit;

    // Use provided path or generate from username (lowercase)
    if (storagePath.isEmpty()) {
        user.storagePath = generateUserStoragePath(username);
    } else {
        user.storagePath = storagePath;
    }

    m_users.append(user);
    saveUsers();

    QDir().mkpath(user.storagePath);
    return true;
}

bool Config::deleteUser(const QString &username)
{
    // Case-insensitive deletion
    QString lowerUsername = username.toLower();

    for (int i = 0; i < m_users.size(); i++) {
        if (m_users[i].username.toLower() == lowerUsername) {
            m_users.removeAt(i);
            saveUsers();
            return true;
        }
    }
    return false;
}

QList<User> Config::getUsers() const
{
    return m_users;
}
