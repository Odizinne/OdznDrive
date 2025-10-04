#include "clientconnection.h"
#include "config.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QFileInfo>
#include <QDir>
#include <QBuffer>
#include <QImage>

ClientConnection::ClientConnection(QWebSocket *socket, FileManager *fileManager, QObject *parent)
    : QObject(parent)
    , m_socket(socket)
    , m_fileManager(fileManager)
    , m_authenticated(false)
    , m_uploadFile(nullptr)
    , m_uploadExpectedSize(0)
    , m_uploadReceivedSize(0)
    , m_downloadFile(nullptr)
    , m_downloadTotalSize(0)
    , m_downloadSentSize(0)
    , m_isZipDownload(false)
{
    connect(m_socket, &QWebSocket::textMessageReceived, this, &ClientConnection::onTextMessageReceived);
    connect(m_socket, &QWebSocket::binaryMessageReceived, this, &ClientConnection::onBinaryMessageReceived);
    connect(m_socket, &QWebSocket::disconnected, this, &ClientConnection::onDisconnected);
    connect(m_socket, &QWebSocket::bytesWritten, this, &ClientConnection::onBytesWritten);
}

ClientConnection::~ClientConnection()
{
    if (m_uploadFile) {
        m_uploadFile->close();
        delete m_uploadFile;
    }

    cleanupDownload();

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
        QString password = params["password"].toString();
        if (authenticate(password)) {
            QJsonObject data;
            data["success"] = true;
            sendResponse("authenticate", data);
        } else {
            sendError("Invalid password");
        }
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
    } else {
        sendError("Unknown command type");
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

    for (const QJsonValue &val : pathsArray) {
        QString path = val.toString();

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
        return; // Silently fail for non-image files
    }

    // Scale image to thumbnail size
    if (image.width() > maxSize || image.height() > maxSize) {
        image = image.scaled(maxSize, maxSize, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    }

    // Convert to JPEG base64
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
    data["name"] = Config::instance().serverName();
    data["version"] = "1.0.0";

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

void ClientConnection::handleCancelDownload(const QJsonObject &params)
{
    Q_UNUSED(params)

    cleanupDownload();

    QJsonObject data;
    data["success"] = true;
    sendResponse("download_cancelled", data);
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

bool ClientConnection::authenticate(const QString &password)
{
    if (password == Config::instance().password()) {
        m_authenticated = true;
        return true;
    }
    return false;
}

void ClientConnection::handleListDirectory(const QJsonObject &params)
{
    QString path = params["path"].toString();
    bool foldersFirst = params["foldersFirst"].toBool();
    QJsonArray files = m_fileManager->listDirectory(path, foldersFirst);

    // Add preview URLs for image files
    for (int i = 0; i < files.size(); ++i) {
        QJsonObject fileObj = files[i].toObject();

        if (!fileObj["isDir"].toBool()) {
            QString fileName = fileObj["name"].toString().toLower();
            if (fileName.endsWith(".jpg") || fileName.endsWith(".jpeg") ||
                fileName.endsWith(".png") || fileName.endsWith(".gif") ||
                fileName.endsWith(".bmp") || fileName.endsWith(".webp")) {

                // Generate preview URL (websocket endpoint)
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

    // Start sending chunks
    for (int i = 0; i < 3 && m_downloadSentSize < m_downloadTotalSize; ++i) {
        sendNextDownloadChunk();
    }
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

    // Get directory name for zip file
    QString dirName = fileInfo.fileName();
    if (dirName.isEmpty()) {
        dirName = "root";
    }

    // Notify client that zipping is starting
    QJsonObject zipData;
    zipData["status"] = "zipping";
    zipData["name"] = dirName;
    sendResponse("download_zipping", zipData);

    // Create zip file using system zip command
    QString zipPath = m_fileManager->createZipFromDirectory(path, dirName);

    if (zipPath.isEmpty()) {
        sendError("Failed to create zip file");
        return;
    }

    // Now download the zip file
    QString absZipPath = m_fileManager->getAbsolutePath(zipPath);
    QFileInfo zipInfo(absZipPath);

    if (!zipInfo.exists()) {
        sendError("Zip file not found");
        return;
    }

    cleanupDownload();

    m_downloadFile = new QFile(absZipPath);
    if (!m_downloadFile->open(QIODevice::ReadOnly)) {
        sendError("Failed to open zip file");
        delete m_downloadFile;
        m_downloadFile = nullptr;
        return;
    }

    m_downloadPath = zipPath;
    m_downloadTotalSize = zipInfo.size();
    m_downloadSentSize = 0;
    m_isZipDownload = true;

    QJsonObject metadata;
    metadata["path"] = zipPath;
    metadata["name"] = dirName + ".zip";
    metadata["size"] = m_downloadTotalSize;
    metadata["isDirectory"] = true;
    sendResponse("download_start", metadata);

    // Start sending chunks
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

        // Delete temporary zip file if this was a directory download
        if (m_isZipDownload) {
            QString absPath = m_fileManager->getAbsolutePath(m_downloadPath);
            QFile::remove(absPath);
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

    qint64 available = m_fileManager->getAvailableSpace(Config::instance().storageLimit());

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
    qint64 total = Config::instance().storageLimit();
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

void ClientConnection::handleDownloadMultiple(const QJsonObject &params)
{
    QJsonArray pathsArray = params["paths"].toArray();
    QString zipName = params["zipName"].toString();

    if (pathsArray.isEmpty()) {
        sendError("No paths provided");
        return;
    }

    QStringList paths;
    for (const QJsonValue &val : pathsArray) {
        paths.append(val.toString());
    }

    // Notify client that zipping is starting
    QJsonObject zipData;
    zipData["status"] = "zipping";
    zipData["name"] = zipName;
    sendResponse("download_zipping", zipData);

    // Create zip file
    QString zipPath = m_fileManager->createZipFromMultiplePaths(paths, zipName);

    if (zipPath.isEmpty()) {
        sendError("Failed to create zip file");
        return;
    }

    // Now download the zip file
    QString absZipPath = m_fileManager->getAbsolutePath(zipPath);
    QFileInfo zipInfo(absZipPath);

    if (!zipInfo.exists()) {
        sendError("Zip file not found");
        return;
    }

    cleanupDownload();

    m_downloadFile = new QFile(absZipPath);
    if (!m_downloadFile->open(QIODevice::ReadOnly)) {
        sendError("Failed to open zip file");
        delete m_downloadFile;
        m_downloadFile = nullptr;
        return;
    }

    m_downloadPath = zipPath;
    m_downloadTotalSize = zipInfo.size();
    m_downloadSentSize = 0;
    m_isZipDownload = true;

    QJsonObject metadata;
    metadata["path"] = zipPath;
    metadata["name"] = zipName + ".zip";
    metadata["size"] = m_downloadTotalSize;
    metadata["isDirectory"] = false;
    metadata["isMultiple"] = true;
    sendResponse("download_start", metadata);

    // Start sending chunks
    for (int i = 0; i < 3 && m_downloadSentSize < m_downloadTotalSize; ++i) {
        sendNextDownloadChunk();
    }
}
