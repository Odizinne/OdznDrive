#ifndef FILESERVER_H
#define FILESERVER_H

#include <QObject>
#include <QWebSocketServer>
#include <QList>
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

private slots:
    void onNewConnection();
    void onClientDisconnected();

private:
    QWebSocketServer *m_server;
    QList<ClientConnection*> m_clients;
    HttpServer *m_httpServer;
    QString getDefaultLocalNetworkUrl();
};

#endif // FILESERVER_H
