#include <QCoreApplication>
#include <QCommandLineParser>
#include <QDebug>
#include "fileserver.h"
#include "config.h"

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);
    QCoreApplication::setOrganizationName("Odizinne");
    QCoreApplication::setApplicationName("OdznDriveServer");
    QCoreApplication::setApplicationVersion("1.0.0");

    QCommandLineParser parser;
    parser.setApplicationDescription("OdznDrive File Transfer Server");
    parser.addHelpOption();
    parser.addVersionOption();

    QCommandLineOption portOption(QStringList() << "p" << "port",
                                  "Server port (default: 8888)", "port");
    parser.addOption(portOption);

    QCommandLineOption storageOption(QStringList() << "s" << "storage",
                                     "Storage root path", "path");
    parser.addOption(storageOption);

    QCommandLineOption limitOption(QStringList() << "l" << "limit",
                                   "Storage limit in MB (default: 10240)", "mb");
    parser.addOption(limitOption);

    QCommandLineOption passwordOption(QStringList() << "pw" << "password",
                                      "Server password", "password");
    parser.addOption(passwordOption);

    QCommandLineOption nameOption(QStringList() << "n" << "name",
                                  "Server name (default: OdznDrive Server)", "name");
    parser.addOption(nameOption);

    parser.process(app);

    Config::instance().load();

    if (parser.isSet(portOption)) {
        Config::instance().setPort(parser.value(portOption).toInt());
    }

    if (parser.isSet(storageOption)) {
        Config::instance().setStorageRoot(parser.value(storageOption));
    }

    if (parser.isSet(limitOption)) {
        qint64 limitMB = parser.value(limitOption).toLongLong();
        Config::instance().setStorageLimit(limitMB * 1024 * 1024);
    }

    if (parser.isSet(passwordOption)) {
        Config::instance().setPassword(parser.value(passwordOption));
    }

    if (parser.isSet(nameOption)) {
        Config::instance().setServerName(parser.value(nameOption));
    }

    Config::instance().save();

    FileServer server;

    if (!server.start()) {
        qCritical() << "Failed to start server";
        return 1;
    }

    qInfo() << "Server started successfully";
    qInfo() << "Server name:" << Config::instance().serverName();
    qInfo() << "Press Ctrl+C to stop";

    return app.exec();
}
