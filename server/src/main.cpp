#include <QCoreApplication>
#include <QCommandLineParser>
#include <QDebug>
#include "fileserver.h"
#include "config.h"
#include "version.h"
#include <QStandardPaths>

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);
    QCoreApplication::setOrganizationName("Odizinne");
    QCoreApplication::setApplicationName("OdznDriveServer");
    QCoreApplication::setApplicationVersion(APP_VERSION_STRING);

    qInfo() << "========================================";
    qInfo() << "          OdznDrive Server" ;
    qInfo() << "========================================";
    qInfo() << "Version:        " << APP_VERSION_STRING;
    qInfo() << "Qt Version:     " << QT_VERSION_STRING;
    qInfo() << "Commit Hash:    " << GIT_COMMIT_HASH;
    qInfo() << "Build Time:     " << BUILD_TIMESTAMP;
    qInfo() << "========================================";

    QCommandLineParser parser;
    parser.setApplicationDescription("OdznDrive File Transfer Server");
    parser.addHelpOption();
    parser.addVersionOption();

    QProcess checkZip;
    checkZip.start("which", QStringList() << "zip");
    checkZip.waitForFinished();

#ifdef Q_OS_LINUX
    if (checkZip.exitCode() != 0) {
        qCritical() << "Error: 'zip' command not found. Please install it and make sure it's in PATH.";
        return 1;
    }
#endif

    QCommandLineOption createUserOption(QStringList() << "create-user",
                                        "Create new user (requires 4-5 args: username password limitMB [path])");
    parser.addOption(createUserOption);

    QCommandLineOption deleteUserOption(QStringList() << "delete-user",
                                        "Delete user (requires 1 arg: username)");
    parser.addOption(deleteUserOption);

    QCommandLineOption listUsersOption(QStringList() << "list-users",
                                       "List all users");
    parser.addOption(listUsersOption);

    parser.process(app);

    Config::instance().initSettings();
    Config::instance().loadUsers();

    if (parser.isSet(createUserOption)) {
        QStringList args = parser.positionalArguments();
        if (args.size() < 4) {
            qCritical() << "Usage: --create-user <username> <password> <isAdmin> <limitMB> [path]";
            qCritical() << "Example: --create-user john password123 true 5000";
            qCritical() << "Example: --create-user john password123 true 5000 /data/john";
            qCritical() << "";
            qCritical() << "If path is not specified, it will be auto-generated as storage/<username>";
            return 1;
        }

        QString username = args[0];
        QString password = args[1];
        bool isAdmin = (args[2].toLower() == "true");
        qint64 limitMB = args[3].toLongLong();
        QString path = args.size() >= 5 ? args[4] : QString();

        if (limitMB <= 0) {
            qCritical() << "Invalid storage limit. Must be positive number.";
            return 1;
        }

        if (Config::instance().createUser(username, password, isAdmin, limitMB, path)) {
            qInfo() << "User created successfully!";
            qInfo() << "Username:      " << username;
            qInfo() << "Is admin:      " << isAdmin;

            User* user = Config::instance().getUser(username);
            if (user) {
                qInfo() << "Storage path:  " << user->storagePath;
            }

            qInfo() << "Storage limit: " << limitMB << "MB";
        } else {
            qCritical() << "Failed to create user (user may already exist)";
            return 1;
        }
        return 0;
    }

    if (parser.isSet(deleteUserOption)) {
        QStringList args = parser.positionalArguments();
        if (args.isEmpty()) {
            qCritical() << "Usage: --delete-user <username>";
            qCritical() << "Example: --delete-user john";
            return 1;
        }

        QString username = args[0];
        if (Config::instance().deleteUser(username)) {
            qInfo() << "User" << username << "deleted successfully";
            qWarning() << "Note: User files were NOT deleted. Please remove manually if needed.";
        } else {
            qCritical() << "User not found:" << username;
            return 1;
        }
        return 0;
    }

    if (parser.isSet(listUsersOption)) {
        QList<User> users = Config::instance().getUsers();
        qInfo() << "";
        qInfo() << "========================================";
        qInfo() << "         Registered Users";
        qInfo() << "========================================";

        if (users.isEmpty()) {
            qInfo() << "No users found.";
        } else {
            for (const User &user : std::as_const(users)) {
                qInfo() << "";
                qInfo() << "Username:      " << user.username;
                qInfo() << "Is admin:      " << user.isAdmin;
                qInfo() << "Storage path:  " << user.storagePath;
                qInfo() << "Storage limit: " << (user.storageLimit / (1024*1024)) << "MB";
                qInfo() << "----------------------------------------";
            }
        }
        qInfo() << "";
        return 0;
    }

    FileServer server;

    if (!server.start()) {
        qCritical() << "Failed to start server";
        return 1;
    }

    qInfo() << "";
    qInfo() << "Server started successfully";
    qInfo() << "Press Ctrl+C to stop";
    qInfo() << "";

    return app.exec();
}
