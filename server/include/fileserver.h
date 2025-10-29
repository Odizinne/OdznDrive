#ifndef FILESERVER_H
#define FILESERVER_H

#include <QObject>
#include <QWebSocketServer>
#include <QList>
#include <QStandardPaths>
#include <QDir>
#include "clientconnection.h"
#include "httpserver.h"

class FileServer : public QObject
{
    Q_OBJECT

public:
    explicit FileServer(QObject *parent = nullptr);
    ~FileServer();

    bool start();
    void stop();

    HttpServer* httpServer() const { return m_httpServer; }
    QString getShareLinksPath() const { return m_shareLinksPath; }

private slots:
    void onNewConnection();
    void onClientDisconnected();

private:
    QWebSocketServer *m_server;
    QList<ClientConnection*> m_clients;
    HttpServer *m_httpServer;
    QString m_shareLinksPath;
    QString getDefaultLocalNetworkUrl();
};

#endif // FILESERVER_H
