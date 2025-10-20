#include "clientconnection.h"
#include "config.h"
#include "protocol.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QFileInfo>
#include <QDir>
#include <QBuffer>
#include <QImage>
#include <QRandomGenerator>
#include <QDirIterator>
#include <QCoreApplication>
#include <QDateTime>
#include "version.h"

ClientConnection::ClientConnection(QWebSocket *socket, FileManager *fileManager, QObject *parent)
    : QObject(parent)
    , m_socket(socket)
    , m_fileManager(nullptr)
    , m_authenticated(false)
    , m_uploadFile(nullptr)
    , m_uploadExpectedSize(0)
    , m_uploadReceivedSize(0)
    , m_downloadFile(nullptr)
    , m_downloadTotalSize(0)
    , m_downloadSentSize(0)
    , m_isZipDownload(false)
    , m_authDelayTimer(new QTimer(this))
    , m_pingTimer(new QTimer(this))
    , m_pongTimeoutTimer(new QTimer(this))
{
    Q_UNUSED(fileManager)
    connect(m_socket, &QWebSocket::textMessageReceived, this, &ClientConnection::onTextMessageReceived);
    connect(m_socket, &QWebSocket::binaryMessageReceived, this, &ClientConnection::onBinaryMessageReceived);
    connect(m_socket, &QWebSocket::disconnected, this, &ClientConnection::onDisconnected);
    connect(m_socket, &QWebSocket::bytesWritten, this, &ClientConnection::onBytesWritten);
    connect(m_authDelayTimer, &QTimer::timeout, this, &ClientConnection::onAuthDelayTimeout);
    m_authDelayTimer->setSingleShot(true);

    connect(m_pingTimer, &QTimer::timeout, this, &ClientConnection::sendPing);
    connect(m_pongTimeoutTimer, &QTimer::timeout, this, &ClientConnection::onPongTimeout);
    m_pingTimer->setInterval(30000);
    m_pongTimeoutTimer->setInterval(10000);
    m_pongTimeoutTimer->setSingleShot(true);
}

ClientConnection::~ClientConnection()
{
    cleanupDownload();

    if (m_isZipDownload && !m_downloadPath.isEmpty()) {
        QFile::remove(m_downloadPath);
    }

    if (m_socket) {
        m_socket->close();
        m_socket->deleteLater();
    }
}

void ClientConnection::onTextMessageReceived(const QString &message)
{
    if (m_waitingForPong) {
        m_pongTimeoutTimer->stop();
        m_waitingForPong = false;
    }

    QJsonDocument doc = QJsonDocument::fromJson(message.toUtf8());
    if (!doc.isObject()) {
        sendError("Invalid JSON format");
        return;
    }

    handleCommand(doc.object());
}

void ClientConnection::onBinaryMessageReceived(const QByteArray &message)
{
    if (!m_authenticated) {
        sendError("Not authenticated");
        return;
    }

    if (!m_uploadFile || !m_uploadFile->isOpen()) {
        sendError("No upload in progress");
        return;
    }

    qint64 written = m_uploadFile->write(message);
    if (written != message.size()) {
        sendError("Failed to write to file");
        m_uploadFile->close();
        delete m_uploadFile;
        m_uploadFile = nullptr;
        m_uploadPath.clear();
        return;
    }

    m_uploadReceivedSize += written;

    if (m_uploadReceivedSize >= m_uploadExpectedSize) {
        m_uploadFile->flush();
        m_uploadFile->close();
        delete m_uploadFile;
        m_uploadFile = nullptr;

        QJsonObject data;
        data["path"] = m_uploadPath;
        data["size"] = m_uploadReceivedSize;
        sendResponse(Protocol::Responses::UPLOAD_COMPLETE, data);

        m_uploadPath.clear();
        m_uploadExpectedSize = 0;
        m_uploadReceivedSize = 0;
    }
}

void ClientConnection::onDisconnected()
{
    m_pingTimer->stop();
    m_pongTimeoutTimer->stop();
    emit disconnected();
}

void ClientConnection::onBytesWritten(qint64 bytes)
{
    Q_UNUSED(bytes)

    if (m_downloadFile && m_downloadFile->isOpen()) {
        if (m_socket->bytesToWrite() < CHUNK_SIZE * 2) {
            sendNextDownloadChunk();
        }
    }
}

void ClientConnection::handleCommand(const QJsonObject &command)
{
    QString type = command["type"].toString();
    QJsonObject params = command["params"].toObject();

    if (type == Protocol::Commands::AUTHENTICATE) {
        handleAuthenticate(params);
        return;
    }
    else if (type == Protocol::Commands::PONG) {
        handlePong(params);
        return;
    }

    if (!m_authenticated) {
        sendError("Not authenticated");
        return;
    }

    if (type == Protocol::Commands::LIST_DIRECTORY) {
        handleListDirectory(params);
    } else if (type == Protocol::Commands::CREATE_DIRECTORY) {
        handleCreateDirectory(params);
    } else if (type == Protocol::Commands::DELETE_FILE) {
        handleDeleteFile(params);
    } else if (type == Protocol::Commands::DELETE_DIRECTORY) {
        handleDeleteDirectory(params);
    } else if (type == Protocol::Commands::DELETE_MULTIPLE) {
        handleDeleteMultiple(params);
    } else if (type == Protocol::Commands::DOWNLOAD_FILE) {
        handleDownloadFile(params);
    } else if (type == Protocol::Commands::DOWNLOAD_DIRECTORY) {
        handleDownloadDirectory(params);
    } else if (type == Protocol::Commands::DOWNLOAD_MULTIPLE) {
        handleDownloadMultiple(params);
    } else if (type == Protocol::Commands::UPLOAD_FILE) {
        handleUploadFile(params);
    } else if (type == Protocol::Commands::CANCEL_UPLOAD) {
        handleCancelUpload(params);
    } else if (type == Protocol::Commands::CANCEL_DOWNLOAD) {
        handleCancelDownload(params);
    } else if (type == Protocol::Commands::MOVE_ITEM) {
        handleMoveItem(params);
    } else if (type == Protocol::Commands::MOVE_MULTIPLE) {
        handleMoveMultiple(params);
    } else if (type == Protocol::Commands::RENAME_ITEM) {
        handleRenameItem(params);
    } else if (type == Protocol::Commands::GET_STORAGE_INFO) {
        handleGetStorageInfo();
    } else if (type == Protocol::Commands::GET_SERVER_INFO) {
        handleGetServerInfo();
    } else if (type == Protocol::Commands::GET_THUMBNAIL) {
        handleGetThumbnail(params);
    } else if (type == Protocol::Commands::GET_FOLDER_TREE) {
        handleGetFolderTree(params);
    } else if (type == Protocol::Commands::CREATE_USER) {
        handleCreateUser(params);
    } else if (type == Protocol::Commands::EDIT_USER) {
        handleEditUser(params);
    } else if (type == Protocol::Commands::DELETE_USER) {
        handleDeleteUser(params);
    } else if (type == Protocol::Commands::GET_USER_LIST) {
        handleGetUserList(params);
    } else if (type == Protocol::Commands::GENERATE_SHARE_LINK) {
        handleGenerateShareLink(params);
    } else if (type == Protocol::Commands::UPLOAD_FOLDER) {
        handleUploadFolder(params);
    } else if (type == Protocol::Commands::UPLOAD_MIXED) {
        handleUploadMixed(params);
    } else {
        sendError("Unknown command type");
    }
}

void ClientConnection::handleAuthenticate(const QJsonObject &params)
{
    QString username = params["username"].toString();
    QString password = params["password"].toString();
    QString clientVersion = params["version"].toString();

    m_pendingAuthUsername = username;
    m_pendingAuthPassword = password;
    m_pendingAuthClientVersion = clientVersion;

    QString errorMessage;
    AuthResult result = authenticate(username, password, clientVersion, errorMessage);

    if (result == AuthResult::Success) {
        User* user = Config::instance().getUser(username);
        QJsonObject data;
        data["success"] = true;
        data["serverVersion"] = APP_VERSION_STRING;
        data["isAdmin"] = user ? user->isAdmin : false;
        sendResponse(Protocol::Responses::AUTHENTICATE, data);

        m_pingTimer->start();
        m_pendingAuthUsername.clear();
        m_pendingAuthPassword.clear();
        m_pendingAuthClientVersion.clear();
    } else {
        m_pendingAuthErrorMessage = errorMessage;
        m_authDelayTimer->start(2000);
    }
}

void ClientConnection::handleDownloadMultiple(const QJsonObject &params)
{
    QJsonArray pathsArray = params["paths"].toArray();
    QStringList paths;

    for (const QJsonValue &val : pathsArray) {
        QString path = val.toString();
        if (m_fileManager->isValidPath(path)) {
            paths.append(path);
        }
    }

    if (paths.isEmpty()) {
        sendError("No valid paths to download");
        return;
    }

    // Create temp directory for zip file
    QString tempDir = QDir::temp().filePath("odzndrive-" + QString::number(QCoreApplication::applicationPid()));
    QDir().mkpath(tempDir);

    QString zipFileName = params["zipName"].toString() + ".zip";
    QString zipPath = QDir(tempDir).filePath(zipFileName);

    // Notify client that zipping has started
    QJsonObject zipData;
    zipData["status"] = "zipping";
    zipData["name"] = zipFileName;
    zipData["count"] = paths.size();
    sendResponse(Protocol::Responses::DOWNLOAD_ZIPPING, zipData);

    // Remove any existing zip file
    QFile::remove(zipPath);

    int compressionLevel = Config::instance().getCompressionLevel();

    // Connect to completion signal (use single-shot connection)
    connect(m_fileManager, &FileManager::zipCreationComplete, this,
            [this, zipFileName](bool success, const QString &zipPath) {
                if (!success) {
                    sendError("Failed to create zip file");
                    QFile::remove(zipPath);
                    return;
                }

                // Check if zip file was created
                QFileInfo zipInfo(zipPath);
                if (!zipInfo.exists()) {
                    sendError("Zip file was not created");
                    return;
                }

                // Clean up any existing download
                cleanupDownload();

                // Open the zip file for download
                m_downloadFile = new QFile(zipPath);
                if (!m_downloadFile->open(QIODevice::ReadOnly)) {
                    sendError("Failed to open zip file");
                    delete m_downloadFile;
                    m_downloadFile = nullptr;
                    QFile::remove(zipPath);
                    return;
                }

                // Set download state
                m_downloadPath = zipPath;
                m_downloadTotalSize = zipInfo.size();
                m_downloadSentSize = 0;
                m_isZipDownload = true;

                // Send download start metadata
                QJsonObject metadata;
                metadata["name"] = zipFileName;
                metadata["size"] = m_downloadTotalSize;
                sendResponse(Protocol::Responses::DOWNLOAD_START, metadata);

                // Start sending chunks
                for (int i = 0; i < 3 && m_downloadSentSize < m_downloadTotalSize; ++i) {
                    sendNextDownloadChunk();
                }
            }, Qt::SingleShotConnection);

    // Start async compression
    m_fileManager->createZipFromMultiplePathsAsync(paths, zipPath, compressionLevel);
}

void ClientConnection::handleDownloadDirectory(const QJsonObject &params)
{
    QString path = params["path"].toString();

    if (!m_fileManager->isValidPath(path)) {
        sendError("Invalid directory path");
        return;
    }

    QString absPath = m_fileManager->getAbsolutePath(path);
    QFileInfo fileInfo(absPath);

    if (!fileInfo.exists() || !fileInfo.isDir()) {
        sendError("Directory not found");
        return;
    }

    QString dirName = fileInfo.fileName();
    if (dirName.isEmpty()) {
        dirName = "root";
    }

    // Create temp directory for zip file
    QString tempDir = QDir::temp().filePath("odzndrive-" + QString::number(QCoreApplication::applicationPid()));
    QDir().mkpath(tempDir);

    QString zipFileName = dirName + ".zip";
    QString zipPath = QDir(tempDir).filePath(zipFileName);

    // Notify client that zipping has started
    QJsonObject zipData;
    zipData["status"] = "zipping";
    zipData["name"] = zipFileName;
    sendResponse(Protocol::Responses::DOWNLOAD_ZIPPING, zipData);

    // Remove any existing zip file
    QFile::remove(zipPath);

    int compressionLevel = Config::instance().getCompressionLevel();

    // Connect to completion signal (use single-shot connection)
    connect(m_fileManager, &FileManager::zipCreationComplete, this,
            [this, zipFileName](bool success, const QString &zipPath) {
                if (!success) {
                    sendError("Failed to create zip file");
                    QFile::remove(zipPath);
                    return;
                }

                // Check if zip file was created
                QFileInfo zipInfo(zipPath);
                if (!zipInfo.exists()) {
                    sendError("Zip file was not created");
                    return;
                }

                // Clean up any existing download
                cleanupDownload();

                // Open the zip file for download
                m_downloadFile = new QFile(zipPath);
                if (!m_downloadFile->open(QIODevice::ReadOnly)) {
                    sendError("Failed to open zip file");
                    delete m_downloadFile;
                    m_downloadFile = nullptr;
                    QFile::remove(zipPath);
                    return;
                }

                // Set download state
                m_downloadPath = zipPath;
                m_downloadTotalSize = zipInfo.size();
                m_downloadSentSize = 0;
                m_isZipDownload = true;

                // Send download start metadata
                QJsonObject metadata;
                metadata["name"] = zipFileName;
                metadata["size"] = m_downloadTotalSize;
                sendResponse(Protocol::Responses::DOWNLOAD_START, metadata);

                // Start sending chunks
                for (int i = 0; i < 3 && m_downloadSentSize < m_downloadTotalSize; ++i) {
                    sendNextDownloadChunk();
                }
            }, Qt::SingleShotConnection);

    // Start async compression
    m_fileManager->createZipFromDirectoryAsync(path, zipPath, compressionLevel);
}

void ClientConnection::handleCancelDownload(const QJsonObject &params)
{
    Q_UNUSED(params)

    // Clean up download state
    cleanupDownload();

    // Clean up temp zip file if it exists
    if (m_isZipDownload && !m_downloadPath.isEmpty()) {
        QFile::remove(m_downloadPath);
    }

    m_downloadPath.clear();
    m_isZipDownload = false;

    QJsonObject data;
    data["success"] = true;
    sendResponse(Protocol::Responses::DOWNLOAD_CANCELLED, data);
}

void ClientConnection::handleRenameItem(const QJsonObject &params)
{
    QString path = params["path"].toString();
    QString newName = params["newName"].toString();

    if (newName.contains('/') || newName.contains('\\')) {
        sendError("Invalid name: cannot contain path separators");
        return;
    }

    if (newName.isEmpty() || newName == "." || newName == "..") {
        sendError("Invalid name");
        return;
    }

    if (m_fileManager->renameItem(path, newName)) {
        QJsonObject data;
        data["path"] = path;
        data["newName"] = newName;
        data["success"] = true;
        sendResponse(Protocol::Responses::RENAME_ITEM, data);
    } else {
        sendError("Failed to rename item");
    }
}

void ClientConnection::handleDeleteMultiple(const QJsonObject &params)
{
    QJsonArray pathsArray = params["paths"].toArray();

    if (pathsArray.isEmpty()) {
        sendError("No paths provided");
        return;
    }

    QStringList deletedFiles;
    QStringList deletedDirs;
    QStringList failed;

    for (int i = 0; i < pathsArray.size(); ++i) {
        QString path = pathsArray[i].toString();

        if (!m_fileManager->isValidPath(path)) {
            failed.append(path);
            continue;
        }

        QString absPath = m_fileManager->getAbsolutePath(path);
        QFileInfo info(absPath);

        if (!info.exists()) {
            failed.append(path);
            continue;
        }

        if (info.isDir()) {
            if (m_fileManager->deleteDirectory(path)) {
                deletedDirs.append(path);
            } else {
                failed.append(path);
            }
        } else {
            if (m_fileManager->deleteFile(path)) {
                deletedFiles.append(path);
            } else {
                failed.append(path);
            }
        }
    }

    QJsonObject data;
    data["deletedFiles"] = QJsonArray::fromStringList(deletedFiles);
    data["deletedDirs"] = QJsonArray::fromStringList(deletedDirs);
    data["failed"] = QJsonArray::fromStringList(failed);
    data["success"] = failed.isEmpty();

    sendResponse(Protocol::Responses::DELETE_MULTIPLE, data);
}

void ClientConnection::handleGetThumbnail(const QJsonObject &params)
{
    QString path = params["path"].toString();
    int maxSize = params["maxSize"].toInt(256);

    if (!m_fileManager->isValidPath(path)) {
        sendError("Invalid file path");
        return;
    }

    QString absPath = m_fileManager->getAbsolutePath(path);
    QImage image(absPath);

    if (image.isNull()) {
        return;
    }

    if (image.width() > maxSize || image.height() > maxSize) {
        image = image.scaled(maxSize, maxSize, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    }

    QByteArray imageData;
    QBuffer buffer(&imageData);
    buffer.open(QIODevice::WriteOnly);
    image.save(&buffer, "JPEG", 85);

    QJsonObject data;
    data["path"] = path;
    data["data"] = QString::fromUtf8(imageData.toBase64());

    sendResponse(Protocol::Responses::THUMBNAIL_DATA, data);
}

void ClientConnection::handleGetServerInfo()
{
    QJsonObject data;
    data["name"] = m_currentUsername;
    data["version"] = APP_VERSION_STRING;

    sendResponse(Protocol::Responses::SERVER_INFO, data);
}

void ClientConnection::handleCancelUpload(const QJsonObject &params)
{
    Q_UNUSED(params)

    if (m_uploadFile) {
        QString absPath = m_uploadFile->fileName();
        m_uploadFile->close();
        delete m_uploadFile;
        m_uploadFile = nullptr;

        QFile::remove(absPath);

        m_uploadPath.clear();
        m_uploadExpectedSize = 0;
        m_uploadReceivedSize = 0;

        QJsonObject data;
        data["success"] = true;
        sendResponse(Protocol::Responses::UPLOAD_CANCELLED, data);
    }
}

void ClientConnection::sendResponse(const QString &type, const QJsonObject &data)
{
    QJsonObject response;
    response["type"] = type;
    response["data"] = data;

    QJsonDocument doc(response);
    m_socket->sendTextMessage(QString::fromUtf8(doc.toJson(QJsonDocument::Compact)));
}

void ClientConnection::sendError(const QString &message)
{
    QJsonObject error;
    error["error"] = message;
    sendResponse(Protocol::Responses::ERROR, error);
}

ClientConnection::AuthResult ClientConnection::authenticate(const QString &username, const QString &password, const QString &clientVersion, QString &errorMessage)
{
    QString clientIP = m_socket->peerAddress().toString();

    User* user = Config::instance().getUser(username);
    if (!user) {
        Config::instance().recordFailedAttempt(clientIP);
        errorMessage = "Invalid username or password";
        return AuthResult::UnknownUser;
    }

    if (!Config::instance().verifyPassword(password, user->passwordHash, user->salt)) {
        Config::instance().recordFailedAttempt(clientIP);
        errorMessage = "Invalid username or password";
        return AuthResult::InvalidPassword;
    }

    QStringList clientParts = clientVersion.split('.');
    QStringList serverParts = QString(APP_VERSION_STRING).split('.');

    if (clientParts.size() < 2 || serverParts.size() < 2) {
        Config::instance().recordFailedAttempt(clientIP);
        errorMessage = "Invalid version format";
        return AuthResult::InvalidVersion;
    }

    int clientMajor = clientParts[0].toInt();
    int clientMinor = clientParts[1].toInt();
    int serverMajor = serverParts[0].toInt();
    int serverMinor = serverParts[1].toInt();

    if (clientMajor != serverMajor || clientMinor != serverMinor) {
        Config::instance().recordFailedAttempt(clientIP);
        errorMessage = QString("Version mismatch: Client %1.%2 incompatible with Server %3.%4")
                           .arg(clientMajor).arg(clientMinor).arg(serverMajor).arg(serverMinor);
        return AuthResult::VersionMismatch;
    }

    m_fileManager = new FileManager(user->storagePath);
    m_currentUsername = username;
    m_authenticated = true;
    Config::instance().clearFailedAttempts(clientIP);

    return AuthResult::Success;
}

void ClientConnection::handleListDirectory(const QJsonObject &params)
{
    QString path = params["path"].toString();
    bool foldersFirst = params["foldersFirst"].toBool();
    QJsonArray files = m_fileManager->listDirectory(path, foldersFirst);

    for (int i = 0; i < files.size(); ++i) {
        QJsonObject fileObj = files[i].toObject();

        if (!fileObj["isDir"].toBool()) {
            QString fileName = fileObj["name"].toString().toLower();
            if (fileName.endsWith(".jpg") || fileName.endsWith(".jpeg") ||
                fileName.endsWith(".png") || fileName.endsWith(".gif") ||
                fileName.endsWith(".bmp") || fileName.endsWith(".webp")) {

                QString previewUrl = "preview://" + fileObj["path"].toString();
                fileObj["previewUrl"] = previewUrl;
                files[i] = fileObj;
            }
        }
    }

    QJsonObject data;
    data["path"] = path;
    data["files"] = files;

    sendResponse(Protocol::Responses::LIST_DIRECTORY, data);
}

void ClientConnection::handleCreateDirectory(const QJsonObject &params)
{
    QString path = params["path"].toString();

    if (m_fileManager->createDirectory(path)) {
        QJsonObject data;
        data["path"] = path;
        data["success"] = true;
        sendResponse(Protocol::Responses::CREATE_DIRECTORY, data);
    } else {
        sendError("Failed to create directory");
    }
}

void ClientConnection::handleDeleteFile(const QJsonObject &params)
{
    QString path = params["path"].toString();

    if (m_fileManager->deleteFile(path)) {
        QJsonObject data;
        data["path"] = path;
        data["success"] = true;
        sendResponse(Protocol::Responses::DELETE_FILE, data);
    } else {
        sendError("Failed to delete file");
    }
}

void ClientConnection::handleDeleteDirectory(const QJsonObject &params)
{
    QString path = params["path"].toString();

    if (m_fileManager->deleteDirectory(path)) {
        QJsonObject data;
        data["path"] = path;
        data["success"] = true;
        sendResponse(Protocol::Responses::DELETE_DIRECTORY, data);
    } else {
        sendError("Failed to delete directory");
    }
}

void ClientConnection::handleDownloadFile(const QJsonObject &params)
{
    QString path = params["path"].toString();

    if (!m_fileManager->isValidPath(path)) {
        sendError("Invalid file path");
        return;
    }

    QString absPath = m_fileManager->getAbsolutePath(path);
    QFileInfo fileInfo(absPath);

    if (!fileInfo.exists() || !fileInfo.isFile()) {
        sendError("File not found");
        return;
    }

    cleanupDownload();

    m_downloadFile = new QFile(absPath);
    if (!m_downloadFile->open(QIODevice::ReadOnly)) {
        sendError("Failed to open file");
        delete m_downloadFile;
        m_downloadFile = nullptr;
        return;
    }

    m_downloadPath = path;
    m_downloadTotalSize = fileInfo.size();
    m_downloadSentSize = 0;
    m_isZipDownload = false;

    QJsonObject metadata;
    metadata["path"] = path;
    metadata["name"] = fileInfo.fileName();
    metadata["size"] = m_downloadTotalSize;
    metadata["isDirectory"] = false;
    sendResponse(Protocol::Responses::DOWNLOAD_START, metadata);

    for (int i = 0; i < 3 && m_downloadSentSize < m_downloadTotalSize; ++i) {
        sendNextDownloadChunk();
    }
}

void ClientConnection::sendNextDownloadChunk()
{
    if (!m_downloadFile || !m_downloadFile->isOpen()) {
        return;
    }

    if (m_downloadSentSize >= m_downloadTotalSize) {
        cleanupDownload();

        QJsonObject data;
        data["path"] = m_downloadPath;
        data["success"] = true;
        sendResponse(Protocol::Responses::DOWNLOAD_COMPLETE, data);

        if (m_isZipDownload) {
            QFile::remove(m_downloadPath);
        }

        m_downloadPath.clear();
        m_isZipDownload = false;
        return;
    }

    if (m_socket->bytesToWrite() >= CHUNK_SIZE * 2) {
        return;
    }

    QByteArray chunk = m_downloadFile->read(CHUNK_SIZE);
    if (chunk.isEmpty() && m_downloadSentSize < m_downloadTotalSize) {
        sendError("Failed to read file chunk");
        cleanupDownload();
        return;
    }

    m_socket->sendBinaryMessage(chunk);
    m_downloadSentSize += chunk.size();
}

void ClientConnection::cleanupDownload()
{
    if (m_downloadFile) {
        m_downloadFile->close();
        delete m_downloadFile;
        m_downloadFile = nullptr;
    }

    m_downloadTotalSize = 0;
    m_downloadSentSize = 0;
}

void ClientConnection::handleUploadFile(const QJsonObject &params)
{
    QString path = params["path"].toString();
    qint64 size = params["size"].toVariant().toLongLong();

    User* user = Config::instance().getUser(m_currentUsername);
    if (!user) {
        sendError("User not found");
        return;
    }

    qint64 available = m_fileManager->getAvailableSpace(user->storageLimit);

    if (size > available) {
        sendError("Insufficient storage space");
        return;
    }

    if (!m_fileManager->isValidPath(path)) {
        sendError("Invalid file path");
        return;
    }

    QString absPath = m_fileManager->getAbsolutePath(path);
    QFileInfo fileInfo(absPath);

    QDir().mkpath(fileInfo.absolutePath());

    if (m_uploadFile) {
        m_uploadFile->close();
        delete m_uploadFile;
        m_uploadFile = nullptr;
    }

    m_uploadFile = new QFile(absPath);
    if (!m_uploadFile->open(QIODevice::WriteOnly)) {
        sendError("Failed to open file for writing");
        delete m_uploadFile;
        m_uploadFile = nullptr;
        return;
    }

    m_uploadPath = path;
    m_uploadExpectedSize = size;
    m_uploadReceivedSize = 0;

    QJsonObject data;
    data["ready"] = true;
    sendResponse(Protocol::Responses::UPLOAD_READY, data);
}

void ClientConnection::handleGetStorageInfo()
{
    User* user = Config::instance().getUser(m_currentUsername);
    if (!user) {
        sendError("User not found");
        return;
    }

    qint64 total = user->storageLimit;
    qint64 used = m_fileManager->getTotalSize();
    qint64 available = total - used;

    QJsonObject data;
    data["total"] = total;
    data["used"] = used;
    data["available"] = available;

    sendResponse(Protocol::Responses::STORAGE_INFO, data);
}

void ClientConnection::handleMoveItem(const QJsonObject &params)
{
    QString fromPath = params["from"].toString();
    QString toPath = params["to"].toString();

    if (m_fileManager->moveItem(fromPath, toPath)) {
        QJsonObject data;
        data["from"] = fromPath;
        data["to"] = toPath;
        data["success"] = true;
        sendResponse(Protocol::Responses::MOVE_ITEM, data);
    } else {
        sendError("Failed to move item");
    }
}

void ClientConnection::onAuthDelayTimeout()
{
    if (!m_pendingAuthUsername.isEmpty()) {
        qWarning() << "Delayed failed auth for user:" << m_pendingAuthUsername;

        sendError(m_pendingAuthErrorMessage);

        m_pendingAuthUsername.clear();
        m_pendingAuthPassword.clear();
        m_pendingAuthClientVersion.clear();
        m_pendingAuthErrorMessage.clear();
    }
}

void ClientConnection::handleCreateUser(const QJsonObject &params)
{
    if (!m_authenticated || !m_fileManager) {
        sendError("Not authenticated");
        return;
    }

    User* currentUser = Config::instance().getUser(m_currentUsername);
    if (!currentUser || !currentUser->isAdmin) {
        sendError("Admin privileges required");
        return;
    }

    QString username = params["username"].toString();
    QString password = params["password"].toString();
    qint64 storageLimit = params["storageLimit"].toVariant().toLongLong();
    bool isAdmin = params["isAdmin"].toBool();

    if (username.isEmpty() || password.isEmpty()) {
        sendError("Username and password are required");
        return;
    }

    if (Config::instance().createUser(username, password, isAdmin, storageLimit)) {
        QJsonObject data;
        data["username"] = username;
        data["success"] = true;
        sendResponse(Protocol::Responses::USER_CREATED, data);
    } else {
        sendError("Failed to create user");
    }
}

void ClientConnection::handleEditUser(const QJsonObject &params)
{
    if (!m_authenticated || !m_fileManager) {
        sendError("Not authenticated");
        return;
    }

    User* currentUser = Config::instance().getUser(m_currentUsername);
    if (!currentUser || !currentUser->isAdmin) {
        sendError("Admin privileges required");
        return;
    }

    QString username = params["username"].toString();
    QString password = params["password"].toString();
    qint64 storageLimit = params["storageLimit"].toVariant().toLongLong();
    bool isAdmin = params["isAdmin"].toBool();

    if (username.isEmpty()) {
        sendError("Username is required");
        return;
    }

    User* user = Config::instance().getUser(username);
    if (!user) {
        sendError("User not found");
        return;
    }

    // Update password if provided
    if (!password.isEmpty()) {
        user->salt = Config::generateSalt();
        user->passwordHash = Config::hashPassword(password, user->salt);
    }

    user->storageLimit = storageLimit * 1024 * 1024;
    user->isAdmin = isAdmin;

    Config::instance().saveUsers();

    QJsonObject data;
    data["username"] = username;
    data["success"] = true;
    sendResponse(Protocol::Responses::USER_EDITED, data);
}

void ClientConnection::handleDeleteUser(const QJsonObject &params)
{
    if (!m_authenticated || !m_fileManager) {
        sendError("Not authenticated");
        return;
    }

    User* currentUser = Config::instance().getUser(m_currentUsername);
    if (!currentUser || !currentUser->isAdmin) {
        sendError("Admin privileges required");
        return;
    }

    QString username = params["username"].toString();

    if (username.isEmpty()) {
        sendError("Username is required");
        return;
    }

    if (username.toLower() == m_currentUsername.toLower()) {
        sendError("Cannot delete your own account");
        return;
    }

    if (Config::instance().deleteUser(username)) {
        QJsonObject data;
        data["username"] = username;
        data["success"] = true;
        sendResponse(Protocol::Responses::USER_DELETED, data);
    } else {
        sendError("Failed to delete user");
    }
}

void ClientConnection::handleGetUserList(const QJsonObject &params)
{
    Q_UNUSED(params)

    if (!m_authenticated || !m_fileManager) {
        sendError("Not authenticated");
        return;
    }

    User* currentUser = Config::instance().getUser(m_currentUsername);
    if (!currentUser || !currentUser->isAdmin) {
        sendError("Admin privileges required");
        return;
    }

    QList<User> users = Config::instance().getUsers();
    QJsonArray usersArray;

    for (const User &user : std::as_const(users)) {
        QJsonObject userObj;
        userObj["username"] = user.username;
        userObj["storageLimit"] = user.storageLimit;
        userObj["password"] = "";
        userObj["isAdmin"] = user.isAdmin;
        usersArray.append(userObj);
    }

    QJsonObject data;
    data["users"] = usersArray;
    sendResponse(Protocol::Responses::USER_LIST, data);
}

void ClientConnection::handleGenerateShareLink(const QJsonObject &params)
{
    if (!m_authenticated || !m_fileManager) {
        sendError("Not authenticated");
        return;
    }
    if (!m_httpServer) {
        sendError("HTTP server not available");
        return;
    }
    QString path = params["path"].toString();
    if (!m_fileManager->isValidPath(path)) {
        sendError("Invalid file path");
        return;
    }
    QString absPath = m_fileManager->getAbsolutePath(path);
    QFileInfo fileInfo(absPath);
    if (!fileInfo.exists() || !fileInfo.isFile()) {
        sendError("File not found");
        return;
    }
    QSettings settings(QCoreApplication::organizationName(), QCoreApplication::applicationName());
    QString httpUrl = settings.value("server/httpUrl", "http://127.0.0.1").toString();
    QString domain = settings.value("server/domain", "").toString();
    bool shortUrl = settings.value("server/shortUrl", false).toBool();

    QString shareLink = m_httpServer->generateShareLink(absPath, httpUrl, domain, shortUrl);
    if (shareLink.isEmpty()) {
        sendError("Failed to generate share link");
        return;
    }

    if (!shareLink.startsWith("http://") && !shareLink.startsWith("https://")) {
        if (!domain.isEmpty()) {
            shareLink = "https://" + shareLink;
        } else {
            QString protocol = "http://";
            if (httpUrl.startsWith("https://")) {
                protocol = "https://";
            }
            shareLink = protocol + shareLink;
        }
    }

    QJsonObject data;
    data["path"] = path;
    data["shareLink"] = shareLink;
    sendResponse(Protocol::Responses::SHARE_LINK_GENERATED, data);
}

void ClientConnection::setHttpServer(HttpServer *httpServer)
{
    m_httpServer = httpServer;
}

void ClientConnection::sendPing()
{
    if (!m_authenticated) {
        return;
    }
    sendResponse(Protocol::Responses::PING, QJsonObject());
    m_waitingForPong = true;
    m_pongTimeoutTimer->start();
}

void ClientConnection::onPongTimeout()
{
    if (m_waitingForPong) {
        qInfo() << "Client" << m_currentUsername << "failed to pong, disconnecting.";
        m_socket->close();
    }
}

void ClientConnection::handleGetFolderTree(const QJsonObject &params)
{
    QString path = params["path"].toString();
    int maxDepth = params["maxDepth"].toInt(-1);

    QJsonObject tree = m_fileManager->getFolderTree(path, maxDepth);

    QJsonObject data;
    data["tree"] = tree;
    sendResponse(Protocol::Responses::FOLDER_TREE, data);
}

void ClientConnection::handlePong(const QJsonObject &params)
{
    Q_UNUSED(params);
}

void ClientConnection::handleMoveMultiple(const QJsonObject &params)
{
    QJsonArray fromPathsArray = params["fromPaths"].toArray();
    QString toPath = params["to"].toString();

    if (fromPathsArray.isEmpty()) {
        sendError("No paths provided");
        return;
    }

    QStringList movedItems;
    QStringList failed;

    for (int i = 0; i < fromPathsArray.size(); ++i) {
        QString fromPath = fromPathsArray[i].toString();

        if (!m_fileManager->isValidPath(fromPath) || !m_fileManager->isValidPath(toPath)) {
            failed.append(fromPath);
            continue;
        }

        if (m_fileManager->moveItem(fromPath, toPath)) {
            movedItems.append(fromPath);
        } else {
            failed.append(fromPath);
        }
    }

    QJsonObject data;
    data["movedItems"] = QJsonArray::fromStringList(movedItems);
    data["failed"] = QJsonArray::fromStringList(failed);
    data["to"] = toPath;
    data["success"] = failed.isEmpty();

    sendResponse(Protocol::Responses::MOVE_MULTIPLE, data);
}

void ClientConnection::handleUploadFolder(const QJsonObject &params)
{
    // For now, just acknowledge - the actual uploads come as individual UPLOAD_FILE commands
    QJsonObject data;
    data["success"] = true;
    sendResponse(Protocol::Responses::FOLDER_UPLOAD_STARTED, data);
}

void ClientConnection::handleUploadMixed(const QJsonObject &params)
{
    // For now, just acknowledge - the actual uploads come as individual UPLOAD_FILE commands
    QJsonObject data;
    data["success"] = true;
    sendResponse(Protocol::Responses::MIXED_UPLOAD_STARTED, data);
}
