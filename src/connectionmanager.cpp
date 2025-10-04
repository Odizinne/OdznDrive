#include "connectionmanager.h"
#include "imagepreviewprovider.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QFile>
#include <QFileInfo>
#include <QUrl>
#include <QBuffer>

ConnectionManager* ConnectionManager::s_instance = nullptr;

ConnectionManager::ConnectionManager(QObject *parent)
    : QObject(parent)
    , m_socket(new QWebSocket(QString(), QWebSocketProtocol::VersionLatest, this))
    , m_connected(false)
    , m_authenticated(false)
    , m_downloadFile(nullptr)
    , m_downloadExpectedSize(0)
    , m_downloadReceivedSize(0)
    , m_isZipping(false)
    , m_uploadFile(nullptr)
    , m_uploadTotalSize(0)
    , m_uploadSentSize(0)
    , m_serverName("Unknown Server")
    , m_imageProvider(nullptr)
{
    connect(m_socket, &QWebSocket::connected, this, &ConnectionManager::onConnected);
    connect(m_socket, &QWebSocket::disconnected, this, &ConnectionManager::onDisconnected);
    connect(m_socket, &QWebSocket::textMessageReceived, this, &ConnectionManager::onTextMessageReceived);
    connect(m_socket, &QWebSocket::binaryMessageReceived, this, &ConnectionManager::onBinaryMessageReceived);
    connect(m_socket, &QWebSocket::errorOccurred, this, &ConnectionManager::onError);
    connect(m_socket, &QWebSocket::bytesWritten, this, &ConnectionManager::onBytesWritten);
}

ConnectionManager* ConnectionManager::create(QQmlEngine *qmlEngine, QJSEngine *jsEngine)
{
    Q_UNUSED(qmlEngine)
    Q_UNUSED(jsEngine)

    return instance();
}

ConnectionManager* ConnectionManager::instance()
{
    if (!s_instance) {
        s_instance = new ConnectionManager();
    }
    return s_instance;
}

void ConnectionManager::setImageProvider(ImagePreviewProvider *provider)
{
    m_imageProvider = provider;
}

void ConnectionManager::connectToServer(const QString &url, const QString &password)
{
    if (m_socket->state() != QAbstractSocket::UnconnectedState) {
        m_socket->abort();
    }

    setConnected(false);
    setAuthenticated(false);

    m_password = password;
    setStatusMessage("Connecting...");

    QUrl wsUrl(url);
    if (wsUrl.scheme().isEmpty()) {
        wsUrl.setScheme("ws");
    }
    if (wsUrl.port() == -1) {
        wsUrl.setPort(8888);
    }

    m_socket->open(wsUrl);
}

void ConnectionManager::disconnect()
{
    m_socket->close();
}

void ConnectionManager::listDirectory(const QString &path)
{
    if (!m_authenticated) {
        emit errorOccurred("Not authenticated");
        return;
    }

    QJsonObject params;
    params["path"] = path;
    sendCommand("list_directory", params);
}

void ConnectionManager::createDirectory(const QString &path)
{
    if (!m_authenticated) {
        emit errorOccurred("Not authenticated");
        return;
    }

    QJsonObject params;
    params["path"] = path;
    sendCommand("create_directory", params);
}

void ConnectionManager::deleteFile(const QString &path)
{
    if (!m_authenticated) {
        emit errorOccurred("Not authenticated");
        return;
    }

    QJsonObject params;
    params["path"] = path;
    sendCommand("delete_file", params);
}

void ConnectionManager::deleteDirectory(const QString &path)
{
    if (!m_authenticated) {
        emit errorOccurred("Not authenticated");
        return;
    }

    QJsonObject params;
    params["path"] = path;
    sendCommand("delete_directory", params);
}

void ConnectionManager::uploadFile(const QString &localPath, const QString &remotePath)
{
    if (!m_authenticated) {
        emit errorOccurred("Not authenticated");
        return;
    }

    QFile file(localPath);
    if (!file.open(QIODevice::ReadOnly)) {
        emit errorOccurred("Cannot open file: " + localPath);
        return;
    }
    file.close();

    bool queueWasEmpty = m_uploadQueue.isEmpty();

    UploadQueueItem item;
    item.localPath = localPath;
    item.remotePath = remotePath;
    m_uploadQueue.enqueue(item);
    emit uploadQueueSizeChanged();

    if (queueWasEmpty && !m_uploadFile && m_uploadLocalPath.isEmpty()) {
        startNextUpload();
    }
}

void ConnectionManager::uploadFiles(const QStringList &localPaths, const QString &remoteDir)
{
    if (!m_authenticated) {
        emit errorOccurred("Not authenticated");
        return;
    }

    for (const QString &localPath : localPaths) {
        QFileInfo fileInfo(localPath);
        QString fileName = fileInfo.fileName();

        QString remotePath = remoteDir;
        if (!remotePath.isEmpty() && !remotePath.endsWith('/')) {
            remotePath += '/';
        }
        remotePath += fileName;

        uploadFile(localPath, remotePath);
    }
}

void ConnectionManager::downloadFile(const QString &remotePath, const QString &localPath)
{
    if (!m_authenticated) {
        emit errorOccurred("Not authenticated");
        return;
    }

    cleanupCurrentDownload();

    m_downloadRemotePath = remotePath;
    m_downloadLocalPath = localPath;

    QJsonObject params;
    params["path"] = remotePath;
    sendCommand("download_file", params);
}

void ConnectionManager::downloadDirectory(const QString &remotePath, const QString &localPath)
{
    if (!m_authenticated) {
        emit errorOccurred("Not authenticated");
        return;
    }

    cleanupCurrentDownload();

    m_downloadRemotePath = remotePath;
    m_downloadLocalPath = localPath;

    QJsonObject params;
    params["path"] = remotePath;
    sendCommand("download_directory", params);
}

void ConnectionManager::getStorageInfo()
{
    if (!m_authenticated) {
        emit errorOccurred("Not authenticated");
        return;
    }

    sendCommand("get_storage_info", QJsonObject());
}

void ConnectionManager::moveItem(const QString &fromPath, const QString &toPath)
{
    if (!m_authenticated) {
        emit errorOccurred("Not authenticated");
        return;
    }

    QJsonObject params;
    params["from"] = fromPath;
    params["to"] = toPath;
    sendCommand("move_item", params);
}

void ConnectionManager::requestThumbnail(const QString &path)
{
    if (!m_authenticated || !m_imageProvider) {
        return;
    }

    // Don't request if already cached
    if (m_imageProvider->hasImage(path)) {
        return;
    }

    QJsonObject params;
    params["path"] = path;
    params["maxSize"] = 256;
    sendCommand("get_thumbnail", params);
}

void ConnectionManager::onConnected()
{
    setConnected(true);
    setStatusMessage("Connected");

    QJsonObject params;
    params["password"] = m_password;
    sendCommand("authenticate", params);
}

void ConnectionManager::onDisconnected()
{
    setConnected(false);
    setAuthenticated(false);
    setStatusMessage("Disconnected");

    cleanupCurrentUpload();
    cleanupCurrentDownload();
    m_uploadQueue.clear();
    emit uploadQueueSizeChanged();

    if (m_imageProvider) {
        m_imageProvider->clear();
    }
}

void ConnectionManager::onTextMessageReceived(const QString &message)
{
    QJsonDocument doc = QJsonDocument::fromJson(message.toUtf8());
    if (doc.isObject()) {
        handleResponse(doc.object());
    }
}

void ConnectionManager::onBinaryMessageReceived(const QByteArray &message)
{
    if (!m_downloadFile || m_downloadLocalPath.isEmpty()) {
        return;
    }

    m_downloadBuffer.append(message);
    m_downloadReceivedSize += message.size();

    if (m_downloadExpectedSize > 0) {
        int progress = (m_downloadReceivedSize * 100) / m_downloadExpectedSize;
        emit downloadProgress(progress);
    }

    if (m_downloadReceivedSize >= m_downloadExpectedSize) {
        if (!m_downloadFile->write(m_downloadBuffer)) {
            emit errorOccurred("Failed to write to file");
        }
        m_downloadFile->flush();
        m_downloadFile->close();
        delete m_downloadFile;
        m_downloadFile = nullptr;

        emit downloadComplete(m_downloadLocalPath);

        m_downloadRemotePath.clear();
        m_downloadLocalPath.clear();
        m_downloadBuffer.clear();
        m_downloadExpectedSize = 0;
        m_downloadReceivedSize = 0;
        setCurrentDownloadFileName("");
        setIsZipping(false);
    } else {
        if (m_downloadBuffer.size() >= CHUNK_SIZE) {
            if (!m_downloadFile->write(m_downloadBuffer)) {
                emit errorOccurred("Failed to write to file");
                cleanupCurrentDownload();
                return;
            }
            m_downloadBuffer.clear();
        }
    }
}

void ConnectionManager::onError(QAbstractSocket::SocketError error)
{
    Q_UNUSED(error)
    setConnected(false);
    setAuthenticated(false);
    setStatusMessage("Error: " + m_socket->errorString());
    emit errorOccurred(m_socket->errorString());
}

void ConnectionManager::onBytesWritten(qint64 bytes)
{
    Q_UNUSED(bytes)

    if (m_uploadFile && m_uploadFile->isOpen()) {
        if (m_socket->bytesToWrite() < CHUNK_SIZE * 2) {
            sendNextChunk();
        }
    }
}

void ConnectionManager::sendNextChunk()
{
    if (!m_uploadFile || !m_uploadFile->isOpen()) {
        return;
    }

    if (m_uploadSentSize >= m_uploadTotalSize) {
        m_uploadFile->close();
        delete m_uploadFile;
        m_uploadFile = nullptr;
        return;
    }

    if (m_socket->bytesToWrite() >= CHUNK_SIZE * 2) {
        return;
    }

    QByteArray chunk = m_uploadFile->read(CHUNK_SIZE);
    if (chunk.isEmpty()) {
        emit errorOccurred("Failed to read file chunk");
        cleanupCurrentUpload();
        startNextUpload();
        return;
    }

    m_socket->sendBinaryMessage(chunk);
    m_uploadSentSize += chunk.size();

    qint64 effectivelyTransferred = m_uploadSentSize - m_socket->bytesToWrite();
    int progress = (effectivelyTransferred * 100) / m_uploadTotalSize;
    if (progress > 100) progress = 100;
    if (progress < 0) progress = 0;

    emit uploadProgress(progress);
}

void ConnectionManager::sendCommand(const QString &type, const QJsonObject &params)
{
    QJsonObject command;
    command["type"] = type;
    command["params"] = params;

    QJsonDocument doc(command);
    m_socket->sendTextMessage(QString::fromUtf8(doc.toJson(QJsonDocument::Compact)));
}

void ConnectionManager::cancelUpload()
{
    cleanupCurrentUpload();

    if (!m_uploadRemotePath.isEmpty()) {
        QJsonObject params;
        params["path"] = m_uploadRemotePath;
        sendCommand("cancel_upload", params);

        m_uploadLocalPath.clear();
        m_uploadRemotePath.clear();
        m_uploadTotalSize = 0;
        m_uploadSentSize = 0;

        setStatusMessage("Upload cancelled");
        emit errorOccurred("Upload cancelled by user");
    }

    startNextUpload();
}

void ConnectionManager::cancelAllUploads()
{
    cancelUpload();
    m_uploadQueue.clear();
    emit uploadQueueSizeChanged();
    setStatusMessage("All uploads cancelled");
}

void ConnectionManager::cancelDownload()
{
    if (!m_downloadRemotePath.isEmpty()) {
        QJsonObject params;
        sendCommand("cancel_download", params);
    }

    cleanupCurrentDownload();
    setStatusMessage("Download cancelled");
    setIsZipping(false);
    emit errorOccurred("Download cancelled by user");
}

void ConnectionManager::startNextUpload()
{
    if (m_uploadQueue.isEmpty()) {
        setCurrentUploadFileName("");
        return;
    }

    UploadQueueItem item = m_uploadQueue.dequeue();
    emit uploadQueueSizeChanged();

    QFile file(item.localPath);
    if (!file.open(QIODevice::ReadOnly)) {
        emit errorOccurred("Cannot open file: " + item.localPath);
        startNextUpload();
        return;
    }

    m_uploadLocalPath = item.localPath;
    m_uploadRemotePath = item.remotePath;
    m_uploadTotalSize = file.size();
    m_uploadSentSize = 0;
    file.close();

    QFileInfo fileInfo(item.localPath);
    setCurrentUploadFileName(fileInfo.fileName());

    QJsonObject params;
    params["path"] = item.remotePath;
    params["size"] = m_uploadTotalSize;
    sendCommand("upload_file", params);
}

void ConnectionManager::cleanupCurrentUpload()
{
    if (m_uploadFile) {
        m_uploadFile->close();
        delete m_uploadFile;
        m_uploadFile = nullptr;
    }
}

void ConnectionManager::cleanupCurrentDownload()
{
    if (m_downloadFile) {
        m_downloadFile->close();
        delete m_downloadFile;
        m_downloadFile = nullptr;
    }

    m_downloadBuffer.clear();
    m_downloadExpectedSize = 0;
    m_downloadReceivedSize = 0;
    m_downloadRemotePath.clear();
    m_downloadLocalPath.clear();
    setCurrentDownloadFileName("");
    setIsZipping(false);
}

void ConnectionManager::setCurrentUploadFileName(const QString &fileName)
{
    if (m_currentUploadFileName != fileName) {
        m_currentUploadFileName = fileName;
        emit currentUploadFileNameChanged();
    }
}

void ConnectionManager::setCurrentDownloadFileName(const QString &fileName)
{
    if (m_currentDownloadFileName != fileName) {
        m_currentDownloadFileName = fileName;
        emit currentDownloadFileNameChanged();
    }
}

void ConnectionManager::setIsZipping(bool zipping)
{
    if (m_isZipping != zipping) {
        m_isZipping = zipping;
        emit isZippingChanged();
    }
}

void ConnectionManager::handleResponse(const QJsonObject &response)
{
    QString type = response["type"].toString();
    QJsonObject data = response["data"].toObject();

    if (type == "error") {
        QString error = data["error"].toString();
        setStatusMessage("Error: " + error);
        emit errorOccurred(error);

        if (!m_authenticated) {
            m_socket->close();
        }

        cleanupCurrentUpload();
        m_uploadLocalPath.clear();
        m_uploadRemotePath.clear();
        m_uploadTotalSize = 0;
        m_uploadSentSize = 0;

        cleanupCurrentDownload();

        startNextUpload();
        return;
    }

    if (type == "authenticate") {
        if (data["success"].toBool()) {
            setAuthenticated(true);
            setStatusMessage("Authenticated");
        } else {
            m_socket->close();
        }
    } else if (type == "list_directory") {
        QString path = data["path"].toString();
        QJsonArray filesArray = data["files"].toArray();
        QVariantList files = filesArray.toVariantList();

        // First emit the directory listing
        emit directoryListed(path, files);

        // Request thumbnails for images (or use cached ones)
        if (m_imageProvider) {
            for (const QVariant &fileVar : files) {
                QVariantMap fileMap = fileVar.toMap();
                if (!fileMap["isDir"].toBool()) {
                    QString fileName = fileMap["name"].toString().toLower();
                    if (fileName.endsWith(".jpg") || fileName.endsWith(".jpeg") ||
                        fileName.endsWith(".png") || fileName.endsWith(".gif") ||
                        fileName.endsWith(".bmp") || fileName.endsWith(".webp")) {

                        QString filePath = fileMap["path"].toString();

                        // If already cached, emit signal immediately
                        if (m_imageProvider->hasImage(filePath)) {
                            emit thumbnailReady(filePath);
                        } else {
                            // Otherwise request from server
                            requestThumbnail(filePath);
                        }
                    }
                }
            }
        }
    } else if (type == "thumbnail_data") {
        if (m_imageProvider) {
            QString path = data["path"].toString();
            QString base64Data = data["data"].toString();

            QByteArray imageData = QByteArray::fromBase64(base64Data.toUtf8());
            QImage image;
            if (image.loadFromData(imageData)) {
                m_imageProvider->addImage(path, image);
                emit thumbnailReady(path);
            }
        }
    } else if (type == "create_directory") {
        emit directoryCreated(data["path"].toString());
    } else if (type == "delete_file") {
        emit fileDeleted(data["path"].toString());
    } else if (type == "delete_directory") {
        emit directoryDeleted(data["path"].toString());
    } else if (type == "move_item") {
        emit itemMoved(data["from"].toString(), data["to"].toString());
    } else if (type == "upload_ready") {
        m_uploadFile = new QFile(m_uploadLocalPath);
        if (m_uploadFile->open(QIODevice::ReadOnly)) {
            emit uploadProgress(0);
            for (int i = 0; i < 3 && m_uploadSentSize < m_uploadTotalSize; ++i) {
                sendNextChunk();
            }
        } else {
            emit errorOccurred("Failed to open file: " + m_uploadLocalPath);
            delete m_uploadFile;
            m_uploadFile = nullptr;
            startNextUpload();
        }
    } else if (type == "upload_complete") {
        emit uploadComplete(data["path"].toString());
        m_uploadLocalPath.clear();
        m_uploadRemotePath.clear();
        m_uploadTotalSize = 0;
        m_uploadSentSize = 0;
        if (m_uploadFile) {
            delete m_uploadFile;
            m_uploadFile = nullptr;
        }

        startNextUpload();
    } else if (type == "upload_cancelled") {
        setStatusMessage("Upload cancelled");
    } else if (type == "download_zipping") {
        QString name = data["name"].toString();
        setCurrentDownloadFileName(name);
        setIsZipping(true);
    } else if (type == "download_start") {
        QString fileName = data["name"].toString();
        m_downloadExpectedSize = data["size"].toVariant().toLongLong();
        m_downloadReceivedSize = 0;
        m_downloadBuffer.clear();

        setCurrentDownloadFileName(fileName);
        setIsZipping(false);

        m_downloadFile = new QFile(m_downloadLocalPath);
        if (!m_downloadFile->open(QIODevice::WriteOnly)) {
            emit errorOccurred("Failed to create download file");
            delete m_downloadFile;
            m_downloadFile = nullptr;
            cleanupCurrentDownload();
            return;
        }

        emit downloadProgress(0);
    } else if (type == "download_complete") {
        // Server confirms download is complete
    } else if (type == "download_cancelled") {
        setStatusMessage("Download cancelled");
    } else if (type == "storage_info") {
        qint64 total = data["total"].toVariant().toLongLong();
        qint64 used = data["used"].toVariant().toLongLong();
        qint64 available = data["available"].toVariant().toLongLong();
        emit storageInfo(total, used, available);
    } else if (type == "server_info") {
        setServerName(data["name"].toString());
    }
}

void ConnectionManager::setConnected(bool connected)
{
    if (m_connected != connected) {
        m_connected = connected;
        emit connectedChanged();
    }
}

void ConnectionManager::setAuthenticated(bool authenticated)
{
    if (m_authenticated != authenticated) {
        m_authenticated = authenticated;
        emit authenticatedChanged();
    }
}

void ConnectionManager::setStatusMessage(const QString &message)
{
    if (m_statusMessage != message) {
        m_statusMessage = message;
        emit statusMessageChanged();
    }
}

void ConnectionManager::getServerInfo()
{
    if (!m_authenticated) {
        emit errorOccurred("Not authenticated");
        return;
    }

    sendCommand("get_server_info", QJsonObject());
}

void ConnectionManager::setServerName(const QString &name)
{
    if (m_serverName != name) {
        m_serverName = name;
        emit serverNameChanged();
    }
}
