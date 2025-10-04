#ifndef CONNECTIONMANAGER_H
#define CONNECTIONMANAGER_H

#include <QObject>
#include <QWebSocket>
#include <QVariantList>
#include <QFile>
#include <QQueue>
#include <qqml.h>

class ImagePreviewProvider;

struct UploadQueueItem {
    QString localPath;
    QString remotePath;
};

class ConnectionManager : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)
    Q_PROPERTY(bool authenticated READ authenticated NOTIFY authenticatedChanged)
    Q_PROPERTY(QString statusMessage READ statusMessage NOTIFY statusMessageChanged)
    Q_PROPERTY(int uploadQueueSize READ uploadQueueSize NOTIFY uploadQueueSizeChanged)
    Q_PROPERTY(QString currentUploadFileName READ currentUploadFileName NOTIFY currentUploadFileNameChanged)
    Q_PROPERTY(QString currentDownloadFileName READ currentDownloadFileName NOTIFY currentDownloadFileNameChanged)
    Q_PROPERTY(bool isZipping READ isZipping NOTIFY isZippingChanged)
    Q_PROPERTY(QString serverName READ serverName NOTIFY serverNameChanged)

public:
    static ConnectionManager* create(QQmlEngine *qmlEngine, QJSEngine *jsEngine);
    static ConnectionManager* instance();

    bool connected() const { return m_connected; }
    bool authenticated() const { return m_authenticated; }
    QString statusMessage() const { return m_statusMessage; }
    int uploadQueueSize() const { return m_uploadQueue.size(); }
    QString currentUploadFileName() const { return m_currentUploadFileName; }
    QString currentDownloadFileName() const { return m_currentDownloadFileName; }
    bool isZipping() const { return m_isZipping; }
    QString serverName() const { return m_serverName; }

    void setImageProvider(ImagePreviewProvider *provider);

    Q_INVOKABLE void connectToServer(const QString &url, const QString &password);
    Q_INVOKABLE void disconnect();

    Q_INVOKABLE void listDirectory(const QString &path);
    Q_INVOKABLE void createDirectory(const QString &path);
    Q_INVOKABLE void deleteFile(const QString &path);
    Q_INVOKABLE void deleteDirectory(const QString &path);
    Q_INVOKABLE void uploadFile(const QString &localPath, const QString &remotePath);
    Q_INVOKABLE void uploadFiles(const QStringList &localPaths, const QString &remoteDir);
    Q_INVOKABLE void downloadFile(const QString &remotePath, const QString &localPath);
    Q_INVOKABLE void downloadDirectory(const QString &remotePath, const QString &localPath);
    Q_INVOKABLE void moveItem(const QString &fromPath, const QString &toPath);
    Q_INVOKABLE void getStorageInfo();
    Q_INVOKABLE void cancelUpload();
    Q_INVOKABLE void cancelAllUploads();
    Q_INVOKABLE void cancelDownload();
    Q_INVOKABLE void getServerInfo();

signals:
    void connectedChanged();
    void authenticatedChanged();
    void statusMessageChanged();
    void uploadQueueSizeChanged();
    void currentUploadFileNameChanged();
    void currentDownloadFileNameChanged();
    void isZippingChanged();

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
    void serverNameChanged();
    void thumbnailReady(const QString &path);

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
    void startNextUpload();
    void cleanupCurrentUpload();
    void cleanupCurrentDownload();
    void setCurrentUploadFileName(const QString &fileName);
    void setCurrentDownloadFileName(const QString &fileName);
    void setIsZipping(bool zipping);
    void setServerName(const QString &name);
    void requestThumbnail(const QString &path);

    static ConnectionManager *s_instance;

    QWebSocket *m_socket;
    bool m_connected;
    bool m_authenticated;
    QString m_statusMessage;
    QString m_password;

    // Download state
    QString m_downloadRemotePath;
    QString m_downloadLocalPath;
    QFile *m_downloadFile;
    QByteArray m_downloadBuffer;
    qint64 m_downloadExpectedSize;
    qint64 m_downloadReceivedSize;
    QString m_currentDownloadFileName;
    bool m_isZipping;

    // Upload state
    QQueue<UploadQueueItem> m_uploadQueue;
    QString m_uploadLocalPath;
    QString m_uploadRemotePath;
    QFile *m_uploadFile;
    qint64 m_uploadTotalSize;
    qint64 m_uploadSentSize;
    QString m_currentUploadFileName;
    QString m_serverName;

    // Image preview
    ImagePreviewProvider *m_imageProvider;

    static const qint64 CHUNK_SIZE = 1024 * 1024; // 1MB chunks
};

#endif // CONNECTIONMANAGER_H
