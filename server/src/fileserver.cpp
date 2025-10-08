#include "fileserver.h"
#include <QWebSocket>
#include <QDebug>
#include <QSettings>
#include <QCoreApplication>
#include <QHostAddress>
#include <QNetworkInterface>

FileServer::FileServer(QObject *parent)
    : QObject(parent)
    , m_server(new QWebSocketServer(QStringLiteral("OdznDrive Server"),
                                    QWebSocketServer::NonSecureMode, this))
    , m_httpServer(new HttpServer(this))
{
    connect(m_server, &QWebSocketServer::newConnection, this, &FileServer::onNewConnection);
}

FileServer::~FileServer()
{
    stop();
}

bool FileServer::start()
{
    QSettings settings(QCoreApplication::organizationName(), QCoreApplication::applicationName());
    int port = settings.value("server/port", 8888).toInt();

    // Get HTTP server settings
    QString httpUrl = settings.value("server/httpUrl", getDefaultLocalNetworkUrl()).toString();
    int httpPort = settings.value("server/httpPort", 8889).toInt();

    if (m_server->listen(QHostAddress::Any, port)) {
        qInfo() << "WebSocket Server listening on port" << port;

        // Start HTTP server
        if (m_httpServer->start(httpUrl, httpPort)) {
            qInfo() << "HTTP Server started for file sharing";
            return true;
        } else {
            qWarning() << "Failed to start HTTP server, but WebSocket server is running";
            return true; // Still return true since WebSocket server is working
        }
    } else {
        qCritical() << "Failed to start WebSocket server:" << m_server->errorString();
        return false;
    }
}

void FileServer::stop()
{
    m_server->close();
    m_httpServer->stop();
    qDeleteAll(m_clients);
    m_clients.clear();
}

void FileServer::onNewConnection()
{
    QWebSocket *socket = m_server->nextPendingConnection();

    qInfo() << "New client connected:" << socket->peerAddress().toString();

    ClientConnection *client = new ClientConnection(socket, nullptr, this);
    client->setHttpServer(m_httpServer);
    connect(client, &ClientConnection::disconnected, this, &FileServer::onClientDisconnected);

    m_clients.append(client);
}

void FileServer::onClientDisconnected()
{
    ClientConnection *client = qobject_cast<ClientConnection*>(sender());
    if (client) {
        qInfo() << "Client disconnected";
        m_clients.removeAll(client);
        client->deleteLater();
    }
}

QString FileServer::getDefaultLocalNetworkUrl()
{
    // Find a suitable local network URL
    QList<QNetworkInterface> interfaces = QNetworkInterface::allInterfaces();

    for (const QNetworkInterface &interface : interfaces) {
        if (interface.flags().testFlag(QNetworkInterface::IsUp) &&
            interface.flags().testFlag(QNetworkInterface::IsRunning) &&
            !interface.flags().testFlag(QNetworkInterface::IsLoopBack)) {

            QList<QNetworkAddressEntry> entries = interface.addressEntries();
            for (const QNetworkAddressEntry &entry : entries) {
                QHostAddress address = entry.ip();
                if (address.protocol() == QAbstractSocket::IPv4Protocol) {
                    return QString("http://%1").arg(address.toString());
                }
            }
        }
    }

    // Fallback to localhost
    return "http://127.0.0.1";
}
