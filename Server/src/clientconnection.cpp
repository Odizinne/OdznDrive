#include "clientconnection.h"
#include "config.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>

ClientConnection::ClientConnection(QWebSocket *socket, FileManager *fileManager, QObject *parent)
    : QObject(parent)
    , m_socket(socket)
    , m_fileManager(fileManager)
    , m_authenticated(false)
    , m_uploadExpectedSize(0)
{
    connect(m_socket, &QWebSocket::textMessageReceived, this, &ClientConnection::onTextMessageReceived);
    connect(m_socket, &QWebSocket::binaryMessageReceived, this, &ClientConnection::onBinaryMessageReceived);
    connect(m_socket, &QWebSocket::disconnected, this, &ClientConnection::onDisconnected);
}

ClientConnection::~ClientConnection()
{
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
    
    if (m_uploadPath.isEmpty()) {
        sendError("No upload in progress");
        return;
    }
    
    m_uploadBuffer.append(message);
    
    if (m_uploadBuffer.size() >= m_uploadExpectedSize) {
        if (m_fileManager->saveFile(m_uploadPath, m_uploadBuffer)) {
            QJsonObject data;
            data["path"] = m_uploadPath;
            data["size"] = m_uploadBuffer.size();
            sendResponse("upload_complete", data);
        } else {
            sendError("Failed to save file");
        }
        
        m_uploadPath.clear();
        m_uploadBuffer.clear();
        m_uploadExpectedSize = 0;
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
    } else if (type == "get_storage_info") {
        handleGetStorageInfo();
    } else {
        sendError("Unknown command type");
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
    
    m_uploadPath = path;
    m_uploadBuffer.clear();
    m_uploadExpectedSize = size;
    
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