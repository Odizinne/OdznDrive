#ifndef CLIENTCONNECTION_H
#define CLIENTCONNECTION_H

#include <QObject>
#include <QWebSocket>
#include <QFile>
#include "filemanager.h"

class ClientConnection : public QObject
{
    Q_OBJECT

public:
    explicit ClientConnection(QWebSocket *socket, FileManager *fileManager, QObject *parent = nullptr);
    ~ClientConnection();

signals:
    void disconnected();

private slots:
    void onTextMessageReceived(const QString &message);
    void onBinaryMessageReceived(const QByteArray &message);
    void onDisconnected();

private:
    void handleCommand(const QJsonObject &command);
    void sendResponse(const QString &type, const QJsonObject &data);
    void sendError(const QString &message);

    bool authenticate(const QString &password);
    void handleListDirectory(const QJsonObject &params);
    void handleCreateDirectory(const QJsonObject &params);
    void handleDeleteFile(const QJsonObject &params);
    void handleDeleteDirectory(const QJsonObject &params);
    void handleDownloadFile(const QJsonObject &params);
    void handleUploadFile(const QJsonObject &params);
    void handleCancelUpload(const QJsonObject &params);
    void handleGetStorageInfo();

    QWebSocket *m_socket;
    FileManager *m_fileManager;
    bool m_authenticated;

    QString m_uploadPath;
    QFile *m_uploadFile;
    qint64 m_uploadExpectedSize;
    qint64 m_uploadReceivedSize;
};

#endif // CLIENTCONNECTION_H
