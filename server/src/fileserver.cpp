#include "fileserver.h"
#include <QWebSocket>
#include <QDebug>
#include <QSettings>
#include <QCoreApplication>

FileServer::FileServer(QObject *parent)
    : QObject(parent)
    , m_server(new QWebSocketServer(QStringLiteral("OdznDrive Server"),
                                    QWebSocketServer::NonSecureMode, this))
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

    if (m_server->listen(QHostAddress::Any, port)) {
        qInfo() << "OdznDrive Server listening on port" << port;
        return true;
    } else {
        qCritical() << "Failed to start server:" << m_server->errorString();
        return false;
    }
}

void FileServer::stop()
{
    m_server->close();
    qDeleteAll(m_clients);
    m_clients.clear();
}

void FileServer::onNewConnection()
{
    QWebSocket *socket = m_server->nextPendingConnection();

    qInfo() << "New client connected:" << socket->peerAddress().toString();

    ClientConnection *client = new ClientConnection(socket, nullptr, this);
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
