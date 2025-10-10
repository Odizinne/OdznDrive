#include "config.h"
#include <QDir>
#include <QStandardPaths>
#include <QCoreApplication>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QFile>
#include <QNetworkInterface>
#include <QCryptographicHash>
#include <QRandomGenerator>
#include <QPasswordDigestor>

Config::Config()
    : m_settings(QCoreApplication::organizationName(), QCoreApplication::applicationName())
{
}

Config& Config::instance()
{
    static Config instance;
    return instance;
}

void Config::initSettings()
{
    if (m_settings.allKeys().isEmpty()) {
        qInfo() << "Creating config file at" << m_settings.fileName();
        m_settings.setValue("server/port", 8888);
        m_settings.setValue("server/httpPort", 8889);
        m_settings.setValue("server/httpUrl", getDefaultLocalNetworkUrl());
        m_settings.setValue("server/domain", "");
        m_settings.setValue("server/shortUrl", false);
    }
}


QString Config::hashPassword(const QString &password, const QByteArray &salt)
{
    QByteArray hash = QPasswordDigestor::deriveKeyPbkdf2(
        QCryptographicHash::Sha256,
        password.toUtf8(),
        salt,
        100000,
        32
        );
    return QString::fromLatin1(hash.toHex());
}

QByteArray Config::generateSalt()
{
    QByteArray salt;
    salt.resize(32);  // 256 bits

    quint32* ptr = reinterpret_cast<quint32*>(salt.data());
    int count = salt.size() / sizeof(quint32);

    for (int i = 0; i < count; ++i) {
        ptr[i] = QRandomGenerator::global()->generate();
    }

    return salt;
}

bool Config::verifyPassword(const QString &password, const QString &hashedPassword, const QByteArray &salt)
{
    QString computedHash = hashPassword(password, salt);
    return computedHash == hashedPassword;
}

void Config::migrateUserToHashedPassword(User &user, const QString &plainPassword)
{
    qInfo() << "Migrating user" << user.username << "to hashed password";

    // Generate salt
    user.salt = generateSalt();

    // Hash the password with the new salt
    user.passwordHash = hashPassword(plainPassword, user.salt);
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
    QString rootStoragePath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QString userPath = QDir(rootStoragePath).filePath("storage/" + username.toLower());
    QDir().mkpath(userPath);
    return userPath;
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

    for (const QJsonValue &value : std::as_const(array)) {
        QJsonObject obj = value.toObject();
        QString ip = obj["ip"].toString();
        QDateTime bannedUntil = QDateTime::fromString(obj["bannedUntil"].toString(), Qt::ISODate);
        int failedAttempts = obj["failedAttempts"].toInt();

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

    if (m_bannedIPs[ip].failedAttempts >= 5) {
        m_bannedIPs[ip].bannedUntil = now.addSecs(30 * 60);
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
        // Create default admin user with hashed password
        User admin;
        admin.username = "admin";
        admin.salt = generateSalt();
        admin.passwordHash = hashPassword("admin123", admin.salt);
        admin.storagePath = generateUserStoragePath("admin");
        admin.storageLimit = 10737418240LL;
        admin.isAdmin = true;
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

    QJsonObject obj = doc.object();
    QJsonArray usersArray = obj["users"].toArray();

    bool needsSave = false;

    for (const QJsonValue &val : std::as_const(usersArray)) {
        QJsonObject obj = val.toObject();
        User user;
        user.username = obj["username"].toString();
        user.storagePath = obj["storagePath"].toString();
        user.storageLimit = obj["storageLimit"].toVariant().toLongLong();
        user.isAdmin = obj["isAdmin"].toBool();

        // Check format and migrate if necessary
        if (obj.contains("passwordHash") && obj.contains("salt")) {
            // New format - already hashed
            user.passwordHash = obj["passwordHash"].toString();
            QString saltBase64 = obj["salt"].toString();
            user.salt = QByteArray::fromBase64(saltBase64.toUtf8());
        } else if (obj.contains("password")) {
            // Old format - plain text password, needs migration
            QString plainPassword = obj["password"].toString();
            migrateUserToHashedPassword(user, plainPassword);
            needsSave = true;
        } else {
            qWarning() << "User" << user.username << "has no password field, skipping";
            continue;
        }

        m_users.append(user);
        QDir().mkpath(user.storagePath);
    }

    qInfo() << "Loaded" << m_users.size() << "user(s)";

    if (needsSave) {
        saveUsers();
        qInfo() << "Password migration completed and saved";
    }
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
    for (const User &user : std::as_const(m_users)) {
        QJsonObject obj;
        obj["username"] = user.username;
        obj["passwordHash"] = user.passwordHash;
        obj["salt"] = QString::fromLatin1(user.salt.toBase64());  // Store salt as base64
        obj["storagePath"] = user.storagePath;
        obj["storageLimit"] = user.storageLimit;
        obj["isAdmin"] = user.isAdmin;
        usersArray.append(obj);
    }

    QJsonObject root;
    root["users"] = usersArray;

    file.write(QJsonDocument(root).toJson());
    file.close();
}

User* Config::getUser(const QString &username)
{
    QString lowerUsername = username.toLower();

    for (User &user : m_users) {
        if (user.username.toLower() == lowerUsername) {
            return &user;
        }
    }
    return nullptr;
}

bool Config::createUser(const QString &username, const QString &password, const bool &isAdmin,
                        const qint64 &storageLimit, const QString &storagePath)
{
    if (getUser(username)) {
        qWarning() << "User already exists:" << username << "(case-insensitive check)";
        return false;
    }

    User user;
    user.username = username;
    user.salt = generateSalt();
    user.passwordHash = hashPassword(password, user.salt);
    user.isAdmin = isAdmin;
    user.storageLimit = storageLimit * 1024 * 1024;

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

QString Config::getDefaultLocalNetworkUrl()
{
    QList<QNetworkInterface> interfaces = QNetworkInterface::allInterfaces();

    for (const QNetworkInterface &interface : std::as_const(interfaces)) {
        if (interface.flags().testFlag(QNetworkInterface::IsUp) &&
            interface.flags().testFlag(QNetworkInterface::IsRunning) &&
            !interface.flags().testFlag(QNetworkInterface::IsLoopBack)) {

            QList<QNetworkAddressEntry> entries = interface.addressEntries();
            for (const QNetworkAddressEntry &entry : std::as_const(entries)) {
                QHostAddress address = entry.ip();
                if (address.protocol() == QAbstractSocket::IPv4Protocol) {
                    return QString("http://%1").arg(address.toString());
                }
            }
        }
    }

    return "http://127.0.0.1";
}
