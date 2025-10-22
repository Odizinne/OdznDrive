#include "connectionmanager.h"
#include "imagepreviewprovider.h"
#include "server/include/protocol.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QFile>
#include <QFileInfo>
#include <QUrl>
#include <QBuffer>
#include <QDirIterator>
#include "version.h"
#include "usermodel.h"

ConnectionManager* ConnectionManager::s_instance = nullptr;

ConnectionManager::ConnectionManager(QObject *parent)
    : QObject(parent)
    , m_socket(new QWebSocket(QString(), QWebSocketProtocol::VersionLatest, this))
    , m_connected(false)
    , m_authenticating(false)
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
    , m_connectionTimer(new QTimer(this))
    , m_currentTransferType(TransferType::None)
    , m_etaTimer(new QTimer(this))
    , m_totalTransferSize(0)
    , m_totalBytesTransferred(0)
    , m_currentSpeed(0)
{
    connect(m_socket, &QWebSocket::connected, this, &ConnectionManager::onConnected);
    connect(m_socket, &QWebSocket::disconnected, this, &ConnectionManager::onDisconnected);
    connect(m_socket, &QWebSocket::textMessageReceived, this, &ConnectionManager::onTextMessageReceived);
    connect(m_socket, &QWebSocket::binaryMessageReceived, this, &ConnectionManager::onBinaryMessageReceived);
    connect(m_socket, &QWebSocket::errorOccurred, this, &ConnectionManager::onError);
    connect(m_socket, &QWebSocket::bytesWritten, this, &ConnectionManager::onBytesWritten);
    connect(this, &ConnectionManager::userListReceived, UserModel::instance(), &UserModel::loadUsers);

    m_connectionTimer->setSingleShot(true);
    m_connectionTimer->setInterval(10000);
    connect(m_connectionTimer, &QTimer::timeout, this, &ConnectionManager::onConnectionTimeout);

    m_etaTimer->setInterval(1000);
    connect(m_etaTimer, &QTimer::timeout, this, &ConnectionManager::updateEta);

    setEta("");
    setSpeed("");
}

ConnectionManager::~ConnectionManager()
{
    cleanupCurrentUpload();
    cleanupCurrentDownload();

    if (m_socket) {
        m_socket->abort();
        delete m_socket;
        m_socket = nullptr;
    }
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

void ConnectionManager::connectToServer(const QString &url, const QString &username, const QString &password)
{
    if (m_socket->state() != QAbstractSocket::UnconnectedState) {
        m_socket->abort();
    }

    setConnected(false);
    setAuthenticating(true);
    setAuthenticated(false);

    m_username = username;
    m_password = password;
    setStatusMessage("Connecting...");

    QString tempUrl = url.trimmed();

    if (!tempUrl.contains("://")) {
        tempUrl.prepend("wss://");
    }

    QUrl wsUrl(tempUrl);
    if (!wsUrl.isValid()) {
        setStatusMessage("Error: Invalid URL format");
        emit errorOccurred("The URL provided is not valid.");
        return;
    }

    QString scheme = wsUrl.scheme().toLower();
    if (scheme == "https") {
        wsUrl.setScheme("wss");
    } else if (scheme == "http") {
        wsUrl.setScheme("ws");
    }

    if (wsUrl.port() == -1) {
        if (wsUrl.scheme() == "wss") {
            wsUrl.setPort(443);
        } else {
            wsUrl.setPort(8888);
        }
    }

    m_connectionTimer->start();
    m_socket->open(wsUrl);
}

void ConnectionManager::disconnect()
{
    m_socket->close();
}

void ConnectionManager::listDirectory(const QString &path, bool foldersFirst)
{
    if (!m_authenticated) {
        emit errorOccurred("Not authenticated");
        return;
    }

    QJsonObject params;
    params["path"] = path;
    params["foldersFirst"] = foldersFirst;
    sendCommand(Protocol::Commands::LIST_DIRECTORY, params);
}

void ConnectionManager::createDirectory(const QString &path)
{
    if (!m_authenticated) {
        emit errorOccurred("Not authenticated");
        return;
    }

    QJsonObject params;
    params["path"] = path;
    sendCommand(Protocol::Commands::CREATE_DIRECTORY, params);
}

void ConnectionManager::deleteFile(const QString &path)
{
    if (!m_authenticated) {
        emit errorOccurred("Not authenticated");
        return;
    }

    QJsonObject params;
    params["path"] = path;
    sendCommand(Protocol::Commands::DELETE_FILE, params);
}

void ConnectionManager::deleteDirectory(const QString &path)
{
    if (!m_authenticated) {
        emit errorOccurred("Not authenticated");
        return;
    }

    QJsonObject params;
    params["path"] = path;
    sendCommand(Protocol::Commands::DELETE_DIRECTORY, params);
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
        // Defer the start to the next event loop iteration to allow
        // uploadFiles() to finish setting up the total size.
        QTimer::singleShot(0, this, &ConnectionManager::startNextUpload);
    }
}

void ConnectionManager::uploadFiles(const QStringList &localPaths, const QString &remoteDir)
{
    if (!m_authenticated) {
        emit errorOccurred("Not authenticated");
        return;
    }

    qint64 newBatchSize = 0;
    for (const QString &localPath : localPaths) {
        QFileInfo fileInfo(localPath);
        newBatchSize += fileInfo.size();

        QString fileName = fileInfo.fileName();
        QString remotePath = remoteDir;
        if (!remotePath.isEmpty() && !remotePath.endsWith('/')) {
            remotePath += '/';
        }
        remotePath += fileName;
        uploadFile(localPath, remotePath);
    }

    if (m_uploadQueue.size() == localPaths.size() && !m_uploadFile) {
        startEtaTracking(TransferType::Upload, newBatchSize);
    } else if (m_currentTransferType == TransferType::Upload) {
        m_totalTransferSize += newBatchSize;
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
    sendCommand(Protocol::Commands::DOWNLOAD_FILE, params);
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
    sendCommand(Protocol::Commands::DOWNLOAD_DIRECTORY, params);
}

void ConnectionManager::getStorageInfo()
{
    if (!m_authenticated) {
        emit errorOccurred("Not authenticated");
        return;
    }

    sendCommand(Protocol::Commands::GET_STORAGE_INFO, QJsonObject());
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
    sendCommand(Protocol::Commands::MOVE_ITEM, params);
}

void ConnectionManager::requestThumbnail(const QString &path)
{
    if (!m_authenticated || !m_imageProvider) {
        return;
    }

    if (m_imageProvider->hasImage(path)) {
        return;
    }

    QJsonObject params;
    params["path"] = path;
    params["maxSize"] = 256;
    sendCommand(Protocol::Commands::GET_THUMBNAIL, params);
}

void ConnectionManager::onConnected()
{
    m_connectionTimer->stop();
    setConnected(true);
    setStatusMessage("Connected");

    QJsonObject params;
    params["username"] = m_username;
    params["password"] = m_password;
    params["version"] = APP_VERSION_STRING;
    sendCommand(Protocol::Commands::AUTHENTICATE, params);
}

void ConnectionManager::onDisconnected()
{
    m_connectionTimer->stop();
    setConnected(false);
    setAuthenticating(false);
    setAuthenticated(false);
    setStatusMessage("Disconnected");

    cleanupCurrentUpload();
    cleanupCurrentDownload();
    m_uploadQueue.clear();
    emit uploadQueueSizeChanged();

    resetEtaTracking();

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

    if (m_currentTransferType == TransferType::Download) {
        m_totalBytesTransferred += message.size();
    }

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
    m_connectionTimer->stop();
    Q_UNUSED(error)
    setConnected(false);
    setAuthenticating(false);
    setAuthenticated(false);
    qDebug() << m_socket->errorString();
    emit errorOccurred(m_socket->errorString());
    resetEtaTracking();
}

void ConnectionManager::onConnectionTimeout()
{
    if (!m_connected) {
        m_socket->abort();
        setConnected(false);
        setAuthenticating(false);
        setAuthenticated(false);
        setStatusMessage("Connection timeout");
        emit errorOccurred("Connection timeout - server did not respond");
        resetEtaTracking();
    }
}

void ConnectionManager::onBytesWritten(qint64 bytes)
{
    if (m_currentTransferType == TransferType::Upload) {
        m_totalBytesTransferred += bytes;

        if (m_totalTransferSize > 0) {
            int progress = (m_totalBytesTransferred * 100) / m_totalTransferSize;

            if (progress >= 100 && !m_uploadQueue.isEmpty()) {
                progress = 99;
            }

            emit uploadProgress(progress);
        }
    }

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
    if (m_uploadLocalPath.isEmpty()) {
        return;
    }

    cleanupCurrentUpload();

    QJsonObject params;
    params["path"] = m_uploadRemotePath;
    sendCommand(Protocol::Commands::CANCEL_UPLOAD, params);
    m_uploadLocalPath.clear();
    m_uploadRemotePath.clear();
    m_uploadTotalSize = 0;
    m_uploadSentSize = 0;
    setCurrentUploadFileName("");

    if (m_uploadQueue.isEmpty()) {
        resetEtaTracking();
        setStatusMessage("Upload cancelled");
    } else {
        startNextUpload();
    }
}

void ConnectionManager::cancelAllUploads()
{
    resetEtaTracking();
    m_uploadQueue.clear();
    emit uploadQueueSizeChanged();
    cleanupCurrentUpload();
    m_uploadLocalPath.clear();
    m_uploadRemotePath.clear();
    m_uploadTotalSize = 0;
    m_uploadSentSize = 0;
    setCurrentUploadFileName("");
    setStatusMessage("All uploads cancelled");
}

void ConnectionManager::cancelDownload()
{
    if (!m_downloadRemotePath.isEmpty()) {
        QJsonObject params;
        sendCommand(Protocol::Commands::CANCEL_DOWNLOAD, params);
    }

    cleanupCurrentDownload();
    setStatusMessage("Download cancelled");
    setIsZipping(false);
    emit errorOccurred("Download cancelled by user");
    resetEtaTracking();
}

void ConnectionManager::startNextUpload()
{
    if (m_uploadQueue.isEmpty()) {
        setCurrentUploadFileName("");
        resetEtaTracking();
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
    sendCommand(Protocol::Commands::UPLOAD_FILE, params);
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

void ConnectionManager::deleteMultiple(const QStringList &paths)
{
    if (!m_authenticated) {
        emit errorOccurred("Not authenticated");
        return;
    }

    if (paths.isEmpty()) {
        emit errorOccurred("No paths provided");
        return;
    }

    QJsonObject params;
    QJsonArray pathsArray;
    for (const QString &path : paths) {
        pathsArray.append(path);
    }
    params["paths"] = pathsArray;

    sendCommand(Protocol::Commands::DELETE_MULTIPLE, params);
}

void ConnectionManager::handleResponse(const QJsonObject &response)
{
    QString type = response["type"].toString();
    QJsonObject data = response["data"].toObject();

    if (type == Protocol::Responses::ERROR) {
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

    if (type == Protocol::Responses::PING) {
        sendCommand(Protocol::Commands::PONG, QJsonObject());
    }

    if (type == Protocol::Responses::AUTHENTICATE) {
        if (data["success"].toBool()) {
            setAuthenticated(true);
            setAuthenticating(false);
            setStatusMessage("Authenticated");
            setIsAdmin(data["isAdmin"].toBool());
        } else {
            m_socket->close();
        }
    } else if (type == Protocol::Responses::LIST_DIRECTORY) {
        QString path = data["path"].toString();
        QJsonArray filesArray = data["files"].toArray();
        QVariantList files = filesArray.toVariantList();

        emit directoryListed(path, files);

        if (m_imageProvider) {
            for (const QVariant &fileVar : std::as_const(files)) {
                QVariantMap fileMap = fileVar.toMap();
                if (!fileMap["isDir"].toBool()) {
                    QString fileName = fileMap["name"].toString().toLower();
                    if (fileName.endsWith(".jpg") || fileName.endsWith(".jpeg") ||
                        fileName.endsWith(".png") || fileName.endsWith(".gif") ||
                        fileName.endsWith(".bmp") || fileName.endsWith(".webp")) {

                        QString filePath = fileMap["path"].toString();

                        if (m_imageProvider->hasImage(filePath)) {
                            emit thumbnailReady(filePath);
                        } else {
                            requestThumbnail(filePath);
                        }
                    }
                }
            }
        }
    } else if (type == Protocol::Responses::THUMBNAIL_DATA) {
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
    } else if (type == Protocol::Responses::CREATE_DIRECTORY) {
        emit directoryCreated(data["path"].toString());
    } else if (type == Protocol::Responses::DELETE_FILE) {
        emit fileDeleted(data["path"].toString());
    } else if (type == Protocol::Responses::DELETE_DIRECTORY) {
        emit directoryDeleted(data["path"].toString());
    } else if (type == Protocol::Responses::DELETE_MULTIPLE) {
        emit multipleDeleted();
    } else if (type == Protocol::Responses::MOVE_ITEM) {
        emit itemMoved(data["from"].toString(), data["to"].toString());
    } else if (type == Protocol::Responses::UPLOAD_READY) {
        m_uploadFile = new QFile(m_uploadLocalPath);
        if (m_uploadFile->open(QIODevice::ReadOnly)) {
            // Only start ETA tracking for the first file
            // Subsequent files will continue using the existing tracking
            if (m_currentTransferType == TransferType::None) {
                // This should have been set by uploadFolder/uploadMixed already
                // But just in case, start tracking here
                startEtaTracking(TransferType::Upload, m_totalTransferSize);
            }

            // Don't emit 0% progress here, let onBytesWritten handle it
            for (int i = 0; i < 3 && m_uploadSentSize < m_uploadTotalSize; ++i) {
                sendNextChunk();
            }
        } else {
            emit errorOccurred("Failed to open file: " + m_uploadLocalPath);
            delete m_uploadFile;
            m_uploadFile = nullptr;
            startNextUpload();
        }
    } else if (type == Protocol::Responses::UPLOAD_COMPLETE) {
        // Individual file completed
        QString completedPath = data["path"].toString();

        m_uploadLocalPath.clear();
        m_uploadRemotePath.clear();
        m_uploadTotalSize = 0;
        m_uploadSentSize = 0;
        if (m_uploadFile) {
            delete m_uploadFile;
            m_uploadFile = nullptr;
        }

        if (m_uploadQueue.isEmpty()) {
            // All uploads done - emit 100% and signal completion
            emit uploadProgress(100);
            setCurrentUploadFileName("");
            resetEtaTracking();

            // Emit the completion signal that triggers UI refresh
            emit uploadComplete(completedPath);
        } else {
            // More files to upload - continue without emitting uploadComplete
            startNextUpload();
        }
    } else if (type == Protocol::Responses::UPLOAD_CANCELLED) {
        setStatusMessage("Upload cancelled");
    } else if (type == Protocol::Responses::DOWNLOAD_ZIPPING) {
        QString name = data["name"].toString();
        setCurrentDownloadFileName(name);
        setIsZipping(true);
        emit downloadZipping(name);
    } else if (type == Protocol::Responses::DOWNLOAD_START) {
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
        startEtaTracking(TransferType::Download, m_downloadExpectedSize);
        emit downloadProgress(0);
    } else if (type == Protocol::Responses::DOWNLOAD_COMPLETE) {
        emit downloadComplete(m_downloadLocalPath);
        cleanupCurrentDownload();
        resetEtaTracking();
    } else if (type == Protocol::Responses::DOWNLOAD_CANCELLED) {
        setStatusMessage("Download cancelled");
    } else if (type == Protocol::Responses::STORAGE_INFO) {
        qint64 total = data["total"].toVariant().toLongLong();
        qint64 used = data["used"].toVariant().toLongLong();
        qint64 available = data["available"].toVariant().toLongLong();
        emit storageInfo(total, used, available);
    } else if (type == Protocol::Responses::RENAME_ITEM) {
        emit itemRenamed(data["path"].toString(), data["newName"].toString());
    } else if (type == Protocol::Responses::SERVER_INFO) {
        setServerName(data["name"].toString());
    } else if (type == Protocol::Responses::USER_CREATED) {
        emit userCreated(data["username"].toString());
        getUserList();
    } else if (type == Protocol::Responses::USER_EDITED) {
        emit userEdited(data["username"].toString());
        getUserList();
    } else if (type == Protocol::Responses::USER_DELETED) {
        emit userDeleted(data["username"].toString());
        getUserList();
    } else if (type == Protocol::Responses::SHARE_LINK_GENERATED) {
        QString path = data["path"].toString();
        QString shareLink = data["shareLink"].toString();
        emit shareLinkGenerated(path, shareLink);
    } else if (type == Protocol::Responses::USER_LIST) {
        QJsonArray usersArray = data["users"].toArray();
        QVariantList users = usersArray.toVariantList();
        emit userListReceived(users);
    } else if (type == Protocol::Responses::FOLDER_TREE) {
        QJsonObject tree = data["tree"].toObject();
        emit folderTreeReceived(tree.toVariantMap());
    } else if (type == Protocol::Responses::MOVE_MULTIPLE) {
        QJsonArray movedArray = data["movedItems"].toArray();
        QStringList movedItems;
        for (int i = 0; i < movedArray.size(); ++i) {
            movedItems.append(movedArray[i].toString());
        }

        QString toPath = data["to"].toString();
        emit multipleMoved(movedItems, toPath);
    }
}

void ConnectionManager::setConnected(bool connected)
{
    if (m_connected != connected) {
        m_connected = connected;
        emit connectedChanged();
    }
}

void ConnectionManager::setAuthenticating(bool authenticating) {
    if (m_authenticating != authenticating) {
        m_authenticating = authenticating;
        emit authenticatingChanged();
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

    sendCommand(Protocol::Commands::GET_SERVER_INFO, QJsonObject());
}

void ConnectionManager::setServerName(const QString &name)
{
    if (m_serverName != name) {
        m_serverName = name;
        emit serverNameChanged();
    }
}

void ConnectionManager::setIsAdmin(const bool &isAdmin)
{
    if (m_isAdmin != isAdmin) {
        m_isAdmin = isAdmin;
        emit isAdminChanged();
    }
}

void ConnectionManager::downloadMultiple(const QStringList &remotePaths, const QString &localPath, const QString &zipName)
{
    if (!m_authenticated) {
        emit errorOccurred("Not authenticated");
        return;
    }

    if (remotePaths.isEmpty()) {
        emit errorOccurred("No files selected");
        return;
    }

    cleanupCurrentDownload();

    m_downloadLocalPath = localPath;
    m_downloadRemotePath = zipName + ".zip";

    setStatusMessage("Preparing download...");

    QJsonObject params;
    QJsonArray pathsArray;
    for (const QString &path : remotePaths) {
        pathsArray.append(path);
    }
    params["paths"] = pathsArray;
    params["zipName"] = zipName;
    sendCommand(Protocol::Commands::DOWNLOAD_MULTIPLE, params);
}

void ConnectionManager::renameItem(const QString &path, const QString &newName)
{
    if (!m_authenticated) {
        emit errorOccurred("Not authenticated");
        return;
    }

    QJsonObject params;
    params["path"] = path;
    params["newName"] = newName;
    sendCommand(Protocol::Commands::RENAME_ITEM, params);
}

void ConnectionManager::createNewUser(const QString &userName, const QString &userPassword, const int &maxStorage, const bool &isAdmin)
{
    if (!m_authenticated) {
        emit errorOccurred("Not authenticated");
        return;
    }

    if (!m_isAdmin) {
        emit errorOccurred("Admin privileges required");
        return;
    }

    QJsonObject params;
    params["username"] = userName;
    params["password"] = userPassword;
    params["storageLimit"] = maxStorage;
    params["isAdmin"] = isAdmin;
    sendCommand(Protocol::Commands::CREATE_USER, params);
}

void ConnectionManager::editExistingUser(const QString &userName, const QString &userPassword, const int &maxStorage, const bool &isAdmin)
{
    if (!m_authenticated) {
        emit errorOccurred("Not authenticated");
        return;
    }

    if (!m_isAdmin) {
        emit errorOccurred("Admin privileges required");
        return;
    }

    QJsonObject params;
    params["username"] = userName;
    params["password"] = userPassword;
    params["storageLimit"] = maxStorage;
    params["isAdmin"] = isAdmin;
    sendCommand(Protocol::Commands::EDIT_USER, params);
}

void ConnectionManager::deleteUser(const QString &userName)
{
    if (!m_authenticated) {
        emit errorOccurred("Not authenticated");
        return;
    }

    if (!m_isAdmin) {
        emit errorOccurred("Admin privileges required");
        return;
    }

    QJsonObject params;
    params["username"] = userName;
    sendCommand(Protocol::Commands::DELETE_USER, params);
}

void ConnectionManager::getUserList()
{
    if (!m_authenticated) {
        emit errorOccurred("Not authenticated");
        return;
    }

    if (!m_isAdmin) {
        emit errorOccurred("Admin privileges required");
        return;
    }

    sendCommand(Protocol::Commands::GET_USER_LIST, QJsonObject());
}

void ConnectionManager::updateEta()
{
    if (m_currentTransferType == TransferType::None || m_totalTransferSize == 0) {
        return;
    }

    QDateTime now = QDateTime::currentDateTime();
    qint64 bytesSinceLastUpdate = m_totalBytesTransferred - m_etaLastBytesTransferred;
    double secondsSinceLastUpdate = m_etaLastUpdateTime.msecsTo(now) / 1000.0;

    if (secondsSinceLastUpdate <= 0) {
        return;
    }

    m_currentSpeed = bytesSinceLastUpdate / secondsSinceLastUpdate;

    m_speedSamples.append(m_currentSpeed);

    while (m_speedSamples.size() > SPEED_SAMPLE_COUNT) {
        m_speedSamples.takeFirst();
    }

    double medianSpeed = calculateMedianSpeed();

    m_etaLastUpdateTime = now;
    m_etaLastBytesTransferred = m_totalBytesTransferred;
    setSpeed(formatSpeed(medianSpeed));

    if (medianSpeed > 0) {
        qint64 remainingBytes = m_totalTransferSize - m_totalBytesTransferred;
        if (remainingBytes > 0) {
            double etaSeconds = remainingBytes / medianSpeed;
            setEta(formatDuration(etaSeconds));
        } else {
            setEta("Almost done...");
        }
    } else {
        setEta("Stalled");
    }
}

double ConnectionManager::calculateMedianSpeed()
{
    if (m_speedSamples.isEmpty()) {
        return 0.0;
    }

    QList<double> sortedSamples = m_speedSamples;
    std::sort(sortedSamples.begin(), sortedSamples.end());

    int count = sortedSamples.size();
    if (count % 2 == 0) {
        return (sortedSamples[count / 2 - 1] + sortedSamples[count / 2]) / 2.0;
    } else {
        return sortedSamples[count / 2];
    }
}

void ConnectionManager::resetEtaTracking()
{
    m_etaTimer->stop();
    m_currentTransferType = TransferType::None;
    m_totalTransferSize = 0;
    m_totalBytesTransferred = 0;
    m_currentSpeed = 0;
    m_speedSamples.clear();
    setEta("");
    setSpeed("");
}

void ConnectionManager::startEtaTracking(TransferType type, qint64 totalSize)
{
    resetEtaTracking();
    m_currentTransferType = type;
    m_totalTransferSize = totalSize;
    m_etaLastUpdateTime = QDateTime::currentDateTime();
    m_etaLastBytesTransferred = 0;
    setEta("Calculating...");
    setSpeed("0 B/s");
    m_etaTimer->start();
}

void ConnectionManager::setEta(const QString &eta)
{
    if (m_etaString != eta) {
        m_etaString = eta;
        emit etaChanged();
    }
}

void ConnectionManager::setSpeed(const QString &speed)
{
    if (m_speedString != speed) {
        m_speedString = speed;
        emit speedChanged();
    }
}

QString ConnectionManager::formatSpeed(double bytesPerSecond)
{
    if (bytesPerSecond < 1024) {
        return QString::number(bytesPerSecond, 'f', 0) + " B/s";
    } else if (bytesPerSecond < 1024 * 1024) {
        return QString::number(bytesPerSecond / 1024, 'f', 1) + " KB/s";
    } else {
        return QString::number(bytesPerSecond / (1024.0 * 1024.0), 'f', 2) + " MB/s";
    }
}

QString ConnectionManager::formatDuration(double seconds)
{
    if (seconds < 0) return "Unknown";

    int totalSeconds = qRound(seconds);
    int hours = totalSeconds / 3600;
    int minutes = (totalSeconds % 3600) / 60;
    int secs = totalSeconds % 60;

    if (hours > 0) {
        return QString("%1h %2m").arg(hours).arg(minutes);
    } else if (minutes > 0) {
        return QString("%1m %2s").arg(minutes).arg(secs);
    } else {
        return QString("%1s").arg(secs);
    }
}

void ConnectionManager::generateShareLink(const QString &path)
{
    if (!m_authenticated) {
        emit errorOccurred("Not authenticated");
        return;
    }

    QJsonObject params;
    params["path"] = path;
    sendCommand(Protocol::Commands::GENERATE_SHARE_LINK, params);
}

void ConnectionManager::getFolderTree(const QString &path, int maxDepth)
{
    if (!m_authenticated) {
        emit errorOccurred("Not authenticated");
        return;
    }

    QJsonObject params;
    params["path"] = path;
    params["maxDepth"] = maxDepth;
    sendCommand(Protocol::Commands::GET_FOLDER_TREE, params);
}

void ConnectionManager::moveMultiple(const QStringList &fromPaths, const QString &toPath)
{
    if (!m_authenticated) {
        emit errorOccurred("Not authenticated");
        return;
    }

    if (fromPaths.isEmpty()) {
        emit errorOccurred("No paths provided");
        return;
    }

    QJsonObject params;
    QJsonArray pathsArray;
    for (const QString &path : fromPaths) {
        pathsArray.append(path);
    }
    params["fromPaths"] = pathsArray;
    params["to"] = toPath;

    sendCommand(Protocol::Commands::MOVE_MULTIPLE, params);
}

void ConnectionManager::uploadFolder(const QString &localFolderPath, const QString &remoteBasePath)
{
    if (!m_authenticated) {
        emit errorOccurred("Not authenticated");
        return;
    }

    QFileInfo folderInfo(localFolderPath);
    if (!folderInfo.exists() || !folderInfo.isDir()) {
        emit errorOccurred("Invalid folder path: " + localFolderPath);
        return;
    }

    QString folderName = folderInfo.fileName();
    QString targetBase = remoteBasePath;
    if (!targetBase.isEmpty() && !targetBase.endsWith('/')) {
        targetBase += '/';
    }
    targetBase += folderName;

    QStringList filesToUpload;
    qint64 totalSize = 0;

    QDirIterator it(localFolderPath, QDir::Files | QDir::NoDotAndDotDot, QDirIterator::Subdirectories);
    while (it.hasNext()) {
        QString filePath = it.next();
        QFileInfo fileInfo(filePath);

        QString relativePath = QDir(localFolderPath).relativeFilePath(filePath);
        QString remotePath = targetBase;
        if (!remotePath.isEmpty() && !remotePath.endsWith('/')) {
            remotePath += '/';
        }
        remotePath += relativePath;

        UploadQueueItem item;
        item.localPath = filePath;
        item.remotePath = remotePath;
        m_uploadQueue.enqueue(item);

        totalSize += fileInfo.size();
    }

    emit uploadQueueSizeChanged();

    if (!m_uploadFile && m_uploadLocalPath.isEmpty()) {
        startEtaTracking(TransferType::Upload, totalSize);
        QTimer::singleShot(0, this, &ConnectionManager::startNextUpload);
    } else if (m_currentTransferType == TransferType::Upload) {
        m_totalTransferSize += totalSize;
    }
}

void ConnectionManager::uploadMixed(const QStringList &localPaths, const QString &remoteBasePath)
{
    if (!m_authenticated) {
        emit errorOccurred("Not authenticated");
        return;
    }

    qint64 totalSize = 0;

    for (const QString &localPath : localPaths) {
        QFileInfo info(localPath);

        if (!info.exists()) {
            qWarning() << "Path does not exist:" << localPath;
            continue;
        }

        if (info.isDir()) {
            QString folderName = info.fileName();
            QString targetBase = remoteBasePath;
            if (!targetBase.isEmpty() && !targetBase.endsWith('/')) {
                targetBase += '/';
            }
            targetBase += folderName;

            QDirIterator it(localPath, QDir::Files | QDir::NoDotAndDotDot, QDirIterator::Subdirectories);
            while (it.hasNext()) {
                QString filePath = it.next();
                QFileInfo fileInfo(filePath);

                QString relativePath = QDir(localPath).relativeFilePath(filePath);
                QString remotePath = targetBase;
                if (!remotePath.isEmpty() && !remotePath.endsWith('/')) {
                    remotePath += '/';
                }
                remotePath += relativePath;

                UploadQueueItem item;
                item.localPath = filePath;
                item.remotePath = remotePath;
                m_uploadQueue.enqueue(item);

                totalSize += fileInfo.size();
            }
        } else {
            QString fileName = info.fileName();
            QString remotePath = remoteBasePath;
            if (!remotePath.isEmpty() && !remotePath.endsWith('/')) {
                remotePath += '/';
            }
            remotePath += fileName;

            UploadQueueItem item;
            item.localPath = localPath;
            item.remotePath = remotePath;
            m_uploadQueue.enqueue(item);

            totalSize += info.size();
        }
    }

    emit uploadQueueSizeChanged();

    if (!m_uploadFile && m_uploadLocalPath.isEmpty()) {
        startEtaTracking(TransferType::Upload, totalSize);
        QTimer::singleShot(0, this, &ConnectionManager::startNextUpload);
    } else if (m_currentTransferType == TransferType::Upload) {
        m_totalTransferSize += totalSize;
    }
}
