#include "clientconnection.h"
#include "config.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QFileInfo>
#include <QDir>

ClientConnection::ClientConnection(QWebSocket *socket, FileManager *fileManager, QObject *parent)
    : QObject(parent)
    , m_socket(socket)
    , m_fileManager(fileManager)
    , m_authenticated(false)
    , m_uploadFile(nullptr)
    , m_uploadExpectedSize(0)
    , m_uploadReceivedSize(0)
{
    connect(m_socket, &QWebSocket::textMessageReceived, this, &ClientConnection::onTextMessageReceived);
    connect(m_socket, &QWebSocket::binaryMessageReceived, this, &ClientConnection::onBinaryMessageReceived);
    connect(m_socket, &QWebSocket::disconnected, this, &ClientConnection::onDisconnected);
}

ClientConnection::~ClientConnection()
{
    if (m_uploadFile) {
        m_uploadFile->close();
        delete m_uploadFile;
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
    } else if (type == "download_file") {
        handleDownloadFile(params);
    } else if (type == "upload_file") {
        handleUploadFile(params);
    } else if (type == "cancel_upload") {
        handleCancelUpload(params);
    } else if (type == "move_item") {
        handleMoveItem(params);
    } else if (type == "get_storage_info") {
        handleGetStorageInfo();
    } else {
        sendError("Unknown command type");
    }
}

void ClientConnection::handleCancelUpload(const QJsonObject &params)
{
    Q_UNUSED(params)

    if (m_uploadFile) {
        QString absPath = m_uploadFile->fileName();
        m_uploadFile->close();
        delete m_uploadFile;
        m_uploadFile = nullptr;

        // Delete the partial file
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
    QJsonArray files = m_fileManager->listDirectory(path);

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
    QByteArray data = m_fileManager->readFile(path);

    if (!data.isEmpty()) {
        QJsonObject metadata;
        metadata["path"] = path;
        metadata["size"] = data.size();
        sendResponse("download_start", metadata);

        m_socket->sendBinaryMessage(data);
    } else {
        sendError("Failed to read file");
    }
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

    // Create parent directory if it doesn't exist
    QDir().mkpath(fileInfo.absolutePath());

    // Clean up any existing upload file
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
