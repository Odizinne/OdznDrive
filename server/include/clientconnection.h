#ifndef CLIENTCONNECTION_H
#define CLIENTCONNECTION_H

#include <QObject>
#include <QWebSocket>
#include <QFile>
#include <QTimer>
#include <QProcess>
#include "filemanager.h"
#include "httpserver.h"

class HttpServer;

class ClientConnection : public QObject
{
    Q_OBJECT

public:
    explicit ClientConnection(QWebSocket *socket, FileManager *fileManager, QObject *parent = nullptr);
    ~ClientConnection();

    void setHttpServer(HttpServer *httpServer);

signals:
    void disconnected();

private slots:
    void onTextMessageReceived(const QString &message);
    void onBinaryMessageReceived(const QByteArray &message);
    void onDisconnected();
    void onBytesWritten(qint64 bytes);
    void onAuthDelayTimeout();

private:
    void handleCommand(const QJsonObject &command);
    void sendResponse(const QString &type, const QJsonObject &data);
    void sendError(const QString &message);

    bool authenticate(const QString &username, const QString &password, const QString &clientVersion);
    void handleListDirectory(const QJsonObject &params);
    void handleCreateDirectory(const QJsonObject &params);
    void handleDeleteFile(const QJsonObject &params);
    void handleDeleteDirectory(const QJsonObject &params);
    void handleDownloadFile(const QJsonObject &params);
    void handleDownloadDirectory(const QJsonObject &params);
    void handleUploadFile(const QJsonObject &params);
    void handleCancelUpload(const QJsonObject &params);
    void handleCancelDownload(const QJsonObject &params);
    void handleMoveItem(const QJsonObject &params);
    void handleGetThumbnail(const QJsonObject &params);
    void handleDownloadMultiple(const QJsonObject &params);
    void handleDeleteMultiple(const QJsonObject &params);
    void handleRenameItem(const QJsonObject &params);
    void handleGetStorageInfo();
    void handleGetServerInfo();
    void handleCreateUser(const QJsonObject &params);
    void handleEditUser(const QJsonObject &params);
    void handleDeleteUser(const QJsonObject &params);
    void handleGetUserList(const QJsonObject &params);
    void handleGenerateShareLink(const QJsonObject &params);

    void sendNextDownloadChunk();
    void cleanupDownload();

    QWebSocket *m_socket;
    FileManager *m_fileManager;
    bool m_authenticated;
    QString m_currentUsername;
    HttpServer *m_httpServer;

    QString m_uploadPath;
    QFile *m_uploadFile;
    qint64 m_uploadExpectedSize;
    qint64 m_uploadReceivedSize;

    QString m_downloadPath;
    QFile *m_downloadFile;
    qint64 m_downloadTotalSize;
    qint64 m_downloadSentSize;
    bool m_isZipDownload;

    QTimer *m_authDelayTimer;
    QString m_pendingAuthUsername;
    QString m_pendingAuthPassword;
    QString m_pendingAuthClientVersion;

    static const qint64 CHUNK_SIZE = 1024 * 1024;

    QProcess* m_zipProcess = nullptr;
    QString m_tempZipPath;
};

#endif // CLIENTCONNECTION_H
