#ifndef FILESERVER_H
#define FILESERVER_H

#include <QObject>
#include <QWebSocketServer>
#include <QList>
#include "clientconnection.h"
#include "filemanager.h"

class FileServer : public QObject
{
    Q_OBJECT

public:
    explicit FileServer(QObject *parent = nullptr);
    ~FileServer();
    
    bool start();
    void stop();

private slots:
    void onNewConnection();
    void onClientDisconnected();

private:
    QWebSocketServer *m_server;
    QList<ClientConnection*> m_clients;
    FileManager *m_fileManager;
};

#endif // FILESERVER_H