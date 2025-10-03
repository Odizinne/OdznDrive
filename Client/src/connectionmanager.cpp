#include "connectionmanager.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QFile>
#include <QFileInfo>
#include <QUrl>

ConnectionManager* ConnectionManager::s_instance = nullptr;

ConnectionManager::ConnectionManager(QObject *parent)
    : QObject(parent)
    , m_socket(new QWebSocket(QString(), QWebSocketProtocol::VersionLatest, this))
    , m_connected(false)
    , m_authenticated(false)
    , m_downloadExpectedSize(0)
    , m_uploadFile(nullptr)
    , m_uploadTotalSize(0)
    , m_uploadSentSize(0)
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

void ConnectionManager::connectToServer(const QString &url, const QString &password)
{
    if (m_connected) {
        disconnect();
    }

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

    // Check if queue is empty BEFORE adding
    bool queueWasEmpty = m_uploadQueue.isEmpty();

    UploadQueueItem item;
    item.localPath = localPath;
    item.remotePath = remotePath;
    m_uploadQueue.enqueue(item);
    emit uploadQueueSizeChanged();

    // Only start upload if queue was empty AND nothing is currently uploading
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

    m_downloadPath = localPath;
    m_downloadBuffer.clear();

    QJsonObject params;
    params["path"] = remotePath;
    sendCommand("download_file", params);
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
    m_uploadQueue.clear();
    emit uploadQueueSizeChanged();
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
    if (m_downloadPath.isEmpty()) {
        return;
    }

    m_downloadBuffer.append(message);

    if (m_downloadExpectedSize > 0) {
        int progress = (m_downloadBuffer.size() * 100) / m_downloadExpectedSize;
        emit downloadProgress(progress);
    }

    if (m_downloadBuffer.size() >= m_downloadExpectedSize) {
        QFile file(m_downloadPath);
        if (file.open(QIODevice::WriteOnly)) {
            file.write(m_downloadBuffer);
            file.close();
            emit downloadComplete(m_downloadPath);
        } else {
            emit errorOccurred("Failed to save file: " + m_downloadPath);
        }

        m_downloadPath.clear();
        m_downloadBuffer.clear();
        m_downloadExpectedSize = 0;
    }
}

void ConnectionManager::onError(QAbstractSocket::SocketError error)
{
    Q_UNUSED(error)
    setStatusMessage("Error: " + m_socket->errorString());
    emit errorOccurred(m_socket->errorString());
}

void ConnectionManager::onBytesWritten(qint64 bytes)
{
    Q_UNUSED(bytes)

    // Only send next chunk if socket buffer is reasonably clear
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

    // Don't send if socket buffer is too full
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

    // Calculate progress based on what's actually been sent through the socket
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

    // Start next upload in queue if any
    startNextUpload();
}

void ConnectionManager::cancelAllUploads()
{
    cancelUpload();
    m_uploadQueue.clear();
    emit uploadQueueSizeChanged();
    setStatusMessage("All uploads cancelled");
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
        startNextUpload(); // Try next file
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

void ConnectionManager::setCurrentUploadFileName(const QString &fileName)
{
    if (m_currentUploadFileName != fileName) {
        m_currentUploadFileName = fileName;
        emit currentUploadFileNameChanged();
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

        // Clean up current upload and try next one
        cleanupCurrentUpload();
        m_uploadLocalPath.clear();
        m_uploadRemotePath.clear();
        m_uploadTotalSize = 0;
        m_uploadSentSize = 0;
        startNextUpload();
        return;
    }

    if (type == "authenticate") {
        if (data["success"].toBool()) {
            setAuthenticated(true);
            setStatusMessage("Authenticated");
        }
    } else if (type == "list_directory") {
        QString path = data["path"].toString();
        QJsonArray filesArray = data["files"].toArray();
        QVariantList files = filesArray.toVariantList();
        emit directoryListed(path, files);
    } else if (type == "create_directory") {
        emit directoryCreated(data["path"].toString());
    } else if (type == "delete_file") {
        emit fileDeleted(data["path"].toString());
    } else if (type == "delete_directory") {
        emit directoryDeleted(data["path"].toString());
    } else if (type == "move_item") {
        emit itemMoved(data["from"].toString(), data["to"].toString());
    } else if (type == "upload_ready") {
        // Start chunked upload
        m_uploadFile = new QFile(m_uploadLocalPath);
        if (m_uploadFile->open(QIODevice::ReadOnly)) {
            emit uploadProgress(0);
            // Send initial chunks to fill the pipeline
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

        // Start next upload in queue
        startNextUpload();
    } else if (type == "upload_cancelled") {
        // Server confirmed cancellation
        setStatusMessage("Upload cancelled");
    } else if (type == "download_start") {
        m_downloadExpectedSize = data["size"].toVariant().toLongLong();
        emit downloadProgress(0);
    } else if (type == "storage_info") {
        qint64 total = data["total"].toVariant().toLongLong();
        qint64 used = data["used"].toVariant().toLongLong();
        qint64 available = data["available"].toVariant().toLongLong();
        emit storageInfo(total, used, available);
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
