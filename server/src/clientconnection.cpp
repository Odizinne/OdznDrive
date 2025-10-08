#include "clientconnection.h"
#include "config.h"
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
    , m_zipProcess(nullptr)
{
    Q_UNUSED(fileManager)
    connect(m_socket, &QWebSocket::textMessageReceived, this, &ClientConnection::onTextMessageReceived);
    connect(m_socket, &QWebSocket::binaryMessageReceived, this, &ClientConnection::onBinaryMessageReceived);
    connect(m_socket, &QWebSocket::disconnected, this, &ClientConnection::onDisconnected);
    connect(m_socket, &QWebSocket::bytesWritten, this, &ClientConnection::onBytesWritten);
    connect(m_authDelayTimer, &QTimer::timeout, this, &ClientConnection::onAuthDelayTimeout);
    m_authDelayTimer->setSingleShot(true);
}

ClientConnection::~ClientConnection()
{
    if (m_uploadFile) {
        m_uploadFile->close();
        delete m_uploadFile;
    }

    if (m_zipProcess) {
        m_zipProcess->kill();
        m_zipProcess->waitForFinished(1000);
        m_zipProcess->deleteLater();
        m_zipProcess = nullptr;
    }
    if (!m_tempZipPath.isEmpty()) {
        QFile::remove(m_tempZipPath);
        m_tempZipPath.clear();
    }

    cleanupDownload();

    if (m_fileManager) {
        delete m_fileManager;
    }

    if (m_socket) {
        m_socket->deleteLater();
    }
}

void ClientConnection::onTextMessageReceived(const QString &message)
{
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
        sendResponse("upload_complete", data);

        m_uploadPath.clear();
        m_uploadExpectedSize = 0;
        m_uploadReceivedSize = 0;
    }
}

void ClientConnection::onDisconnected()
{
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

    if (type == "authenticate") {
        handleAuthenticate(params);
        return;
    }
    if (!m_authenticated) {
        sendError("Not authenticated");
        return;
    }
    if (type == "list_directory") {
        handleListDirectory(params);
    } else if (type == "create_directory") {
        handleCreateDirectory(params);
    } else if (type == "delete_file") {
        handleDeleteFile(params);
    } else if (type == "delete_directory") {
        handleDeleteDirectory(params);
    } else if (type == "delete_multiple") {
        handleDeleteMultiple(params);
    } else if (type == "download_file") {
        handleDownloadFile(params);
    } else if (type == "download_directory") {
        handleDownloadDirectory(params);
    } else if (type == "upload_file") {
        handleUploadFile(params);
    } else if (type == "cancel_upload") {
        handleCancelUpload(params);
    } else if (type == "cancel_download") {
        handleCancelDownload(params);
    } else if (type == "move_item") {
        handleMoveItem(params);
    } else if (type == "get_storage_info") {
        handleGetStorageInfo();
    } else if (type == "get_server_info") {
        handleGetServerInfo();
    } else if (type == "get_thumbnail") {
        handleGetThumbnail(params);
    } else if (type == "download_multiple") {
        handleDownloadMultiple(params);
    } else if (type == "rename_item") {
        handleRenameItem(params);
    } else if (type == "create_user") {
        handleCreateUser(params);
    } else if (type == "edit_user") {
        handleEditUser(params);
    } else if (type == "delete_user") {
        handleDeleteUser(params);
    } else if (type == "get_user_list") {
        handleGetUserList(params);
    } else if (type == "generate_share_link") {
        handleGenerateShareLink(params);
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
        sendResponse("authenticate", data);

        m_pendingAuthUsername.clear();
        m_pendingAuthPassword.clear();
        m_pendingAuthClientVersion.clear();
    } else {
        m_authDelayTimer->start(2000);
    }
}

void ClientConnection::handleDownloadMultiple(const QJsonObject &params)
{
    QJsonArray pathsArray = params["paths"].toArray();
    QString zipName = params["zipName"].toString();

    if (pathsArray.isEmpty()) {
        sendError("No paths provided");
        return;
    }

    QStringList paths;
    for (int i = 0; i < pathsArray.size(); ++i) {
        paths.append(pathsArray[i].toString());
    }

    QJsonObject zipData;
    zipData["status"] = "zipping";
    zipData["name"] = zipName;
    sendResponse("download_zipping", zipData);

    if (m_zipProcess) {
        m_zipProcess->kill();
        m_zipProcess->deleteLater();
        m_zipProcess = nullptr;
    }
    if (!m_tempZipPath.isEmpty()) {
        QFile::remove(m_tempZipPath);
        m_tempZipPath.clear();
    }

    m_zipProcess = m_fileManager->createZipFromMultiplePaths(paths, zipName, m_tempZipPath);

    if (!m_zipProcess || m_tempZipPath.isEmpty()) {
        sendError("Failed to start zip creation");
        if (m_zipProcess) {
            m_zipProcess->deleteLater();
            m_zipProcess = nullptr;
        }
        return;
    }

    connect(m_zipProcess, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), this, [this, zipName](int exitCode, QProcess::ExitStatus exitStatus) {
        Q_UNUSED(exitStatus)
        m_zipProcess->deleteLater();
        m_zipProcess = nullptr;

        if (exitCode != 0) {
            qWarning() << "Zip process failed with exit code" << exitCode;
            sendError("Zip creation failed on server.");
            QFile::remove(m_tempZipPath);
            m_tempZipPath.clear();
            return;
        }

        qInfo() << "Zip creation successful for" << m_tempZipPath;
        QFileInfo zipInfo(m_tempZipPath);
        if (!zipInfo.exists()) {
            sendError("Zip file not found after creation.");
            return;
        }

        cleanupDownload();

        m_downloadFile = new QFile(m_tempZipPath);
        if (!m_downloadFile->open(QIODevice::ReadOnly)) {
            sendError("Failed to open zip file: " + m_tempZipPath);
            delete m_downloadFile;
            m_downloadFile = nullptr;
            QFile::remove(m_tempZipPath);
            m_tempZipPath.clear();
            return;
        }

        m_downloadPath = m_tempZipPath;
        m_downloadTotalSize = zipInfo.size();
        m_downloadSentSize = 0;
        m_isZipDownload = true;

        QJsonObject metadata;
        metadata["path"] = zipName + ".zip";
        metadata["name"] = zipName + ".zip";
        metadata["size"] = m_downloadTotalSize;
        metadata["isDirectory"] = false;
        metadata["isMultiple"] = true;
        sendResponse("download_start", metadata);

        for (int i = 0; i < 3 && m_downloadSentSize < m_downloadTotalSize; ++i) {
            sendNextDownloadChunk();
        }
    });
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

    QJsonObject zipData;
    zipData["status"] = "zipping";
    zipData["name"] = dirName;
    sendResponse("download_zipping", zipData);

    if (m_zipProcess) {
        m_zipProcess->kill();
        m_zipProcess->deleteLater();
        m_zipProcess = nullptr;
    }
    if (!m_tempZipPath.isEmpty()) {
        QFile::remove(m_tempZipPath);
        m_tempZipPath.clear();
    }

    m_zipProcess = m_fileManager->createZipFromDirectory(path, dirName, m_tempZipPath);

    if (!m_zipProcess || m_tempZipPath.isEmpty()) {
        sendError("Failed to start zip creation");
        if (m_zipProcess) {
            m_zipProcess->deleteLater();
            m_zipProcess = nullptr;
        }
        return;
    }

    connect(m_zipProcess, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), this, [this, dirName](int exitCode, QProcess::ExitStatus exitStatus) {
        Q_UNUSED(exitStatus)
        m_zipProcess->deleteLater();
        m_zipProcess = nullptr;

        if (exitCode != 0) {
            qWarning() << "Zip process failed with exit code" << exitCode;
            sendError("Zip creation failed on server.");
            QFile::remove(m_tempZipPath);
            m_tempZipPath.clear();
            return;
        }

        qInfo() << "Zip creation successful for" << m_tempZipPath;
        QFileInfo zipInfo(m_tempZipPath);
        if (!zipInfo.exists()) {
            sendError("Zip file not found after creation.");
            return;
        }

        cleanupDownload();

        m_downloadFile = new QFile(m_tempZipPath);
        if (!m_downloadFile->open(QIODevice::ReadOnly)) {
            sendError("Failed to open zip file: " + m_tempZipPath);
            delete m_downloadFile;
            m_downloadFile = nullptr;
            QFile::remove(m_tempZipPath);
            m_tempZipPath.clear();
            return;
        }

        m_downloadPath = m_tempZipPath;
        m_downloadTotalSize = zipInfo.size();
        m_downloadSentSize = 0;
        m_isZipDownload = true;

        QJsonObject metadata;
        metadata["path"] = dirName + ".zip";
        metadata["name"] = dirName + ".zip";
        metadata["size"] = m_downloadTotalSize;
        metadata["isDirectory"] = true;
        sendResponse("download_start", metadata);

        for (int i = 0; i < 3 && m_downloadSentSize < m_downloadTotalSize; ++i) {
            sendNextDownloadChunk();
        }
    });
}

void ClientConnection::handleCancelDownload(const QJsonObject &params)
{
    Q_UNUSED(params)

    if (m_zipProcess && m_zipProcess->state() == QProcess::Running) {
        qInfo() << "Canceling zip process for download.";
        m_zipProcess->kill();
        m_zipProcess->waitForFinished(1000);
        m_zipProcess->deleteLater();
        m_zipProcess = nullptr;
    }

    if (!m_tempZipPath.isEmpty()) {
        QFile::remove(m_tempZipPath);
        m_tempZipPath.clear();
    }

    cleanupDownload();

    QJsonObject data;
    data["success"] = true;
    sendResponse("download_cancelled", data);
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
        sendResponse("rename_item", data);
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

    sendResponse("delete_multiple", data);
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

    sendResponse("thumbnail_data", data);
}

void ClientConnection::handleGetServerInfo()
{
    QJsonObject data;
    data["name"] = m_currentUsername;
    data["version"] = APP_VERSION_STRING;

    sendResponse("server_info", data);
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
        sendResponse("upload_cancelled", data);
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
    sendResponse("error", error);
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

    if (password != user->password) {
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

    sendResponse("list_directory", data);
}

void ClientConnection::handleCreateDirectory(const QJsonObject &params)
{
    QString path = params["path"].toString();

    if (m_fileManager->createDirectory(path)) {
        QJsonObject data;
        data["path"] = path;
        data["success"] = true;
        sendResponse("create_directory", data);
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
        sendResponse("delete_file", data);
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
        sendResponse("delete_directory", data);
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
    sendResponse("download_start", metadata);

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
        sendResponse("download_complete", data);

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
    sendResponse("upload_ready", data);
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

    sendResponse("storage_info", data);
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
        sendResponse("move_item", data);
    } else {
        sendError("Failed to move item");
    }
}

void ClientConnection::onAuthDelayTimeout()
{
    if (!m_pendingAuthUsername.isEmpty()) {
        qWarning() << "Delayed failed auth for user:" << m_pendingAuthUsername;

        sendError("Invalid username or password");

        m_pendingAuthUsername.clear();
        m_pendingAuthPassword.clear();
        m_pendingAuthClientVersion.clear();
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
        sendResponse("user_created", data);
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

    if (!password.isEmpty()) {
        user->password = password;
    }
    user->storageLimit = storageLimit * 1024 * 1024;
    user->isAdmin = isAdmin;

    Config::instance().saveUsers();

    QJsonObject data;
    data["username"] = username;
    data["success"] = true;
    sendResponse("user_edited", data);
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
        sendResponse("user_deleted", data);
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
        userObj["password"] = user.password;
        userObj["isAdmin"] = user.isAdmin;
        usersArray.append(userObj);
    }

    QJsonObject data;
    data["users"] = usersArray;
    sendResponse("user_list", data);
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

    QJsonObject data;
    data["path"] = path;
    data["shareLink"] = shareLink;
    sendResponse("share_link_generated", data);
}

void ClientConnection::setHttpServer(HttpServer *httpServer)
{
    m_httpServer = httpServer;
}
