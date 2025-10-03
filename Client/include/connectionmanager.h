#ifndef CONNECTIONMANAGER_H
#define CONNECTIONMANAGER_H

#include <QObject>
#include <QWebSocket>
#include <QVariantList>
#include <QFile>
#include <qqml.h>

class ConnectionManager : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)
    Q_PROPERTY(bool authenticated READ authenticated NOTIFY authenticatedChanged)
    Q_PROPERTY(QString statusMessage READ statusMessage NOTIFY statusMessageChanged)

public:
    static ConnectionManager* create(QQmlEngine *qmlEngine, QJSEngine *jsEngine);
    static ConnectionManager* instance();

    bool connected() const { return m_connected; }
    bool authenticated() const { return m_authenticated; }
    QString statusMessage() const { return m_statusMessage; }

    Q_INVOKABLE void connectToServer(const QString &url, const QString &password);
    Q_INVOKABLE void disconnect();

    Q_INVOKABLE void listDirectory(const QString &path);
    Q_INVOKABLE void createDirectory(const QString &path);
    Q_INVOKABLE void deleteFile(const QString &path);
    Q_INVOKABLE void deleteDirectory(const QString &path);
    Q_INVOKABLE void uploadFile(const QString &localPath, const QString &remotePath);
    Q_INVOKABLE void downloadFile(const QString &remotePath, const QString &localPath);
    Q_INVOKABLE void moveItem(const QString &fromPath, const QString &toPath);
    Q_INVOKABLE void getStorageInfo();
    Q_INVOKABLE void cancelUpload();

signals:
    void connectedChanged();
    void authenticatedChanged();
    void statusMessageChanged();

    void directoryListed(const QString &path, const QVariantList &files);
    void directoryCreated(const QString &path);
    void fileDeleted(const QString &path);
    void directoryDeleted(const QString &path);
    void uploadProgress(int percentage);
    void uploadComplete(const QString &path);
    void downloadProgress(int percentage);
    void downloadComplete(const QString &path);
    void itemMoved(const QString &fromPath, const QString &toPath);
    void storageInfo(qint64 total, qint64 used, qint64 available);
    void errorOccurred(const QString &error);

private slots:
    void onConnected();
    void onDisconnected();
    void onTextMessageReceived(const QString &message);
    void onBinaryMessageReceived(const QByteArray &message);
    void onError(QAbstractSocket::SocketError error);
    void onBytesWritten(qint64 bytes);

private:
    explicit ConnectionManager(QObject *parent = nullptr);
    ConnectionManager(const ConnectionManager&) = delete;
    ConnectionManager& operator=(const ConnectionManager&) = delete;

    void sendCommand(const QString &type, const QJsonObject &params);
    void handleResponse(const QJsonObject &response);
    void setConnected(bool connected);
    void setAuthenticated(bool authenticated);
    void setStatusMessage(const QString &message);
    void sendNextChunk();

    static ConnectionManager *s_instance;

    QWebSocket *m_socket;
    bool m_connected;
    bool m_authenticated;
    QString m_statusMessage;
    QString m_password;

    QString m_downloadPath;
    QByteArray m_downloadBuffer;
    qint64 m_downloadExpectedSize;

    QString m_uploadLocalPath;
    QString m_uploadRemotePath;
    QFile *m_uploadFile;
    qint64 m_uploadTotalSize;
    qint64 m_uploadSentSize;

    static const qint64 CHUNK_SIZE = 1024 * 1024; // 1MB chunks
};

#endif // CONNECTIONMANAGER_H
