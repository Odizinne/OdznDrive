#include "httpserver.h"
#include <QNetworkInterface>
#include <QCoreApplication>
#include <QDateTime>
#include <QUuid>
#include <QUrl>
#include <QHostAddress>
#include <QRegularExpression>
#include <QMimeDatabase>
#include <QMimeType>
#include <QHttpServerResponder>
#include <QSettings>

HttpServer::HttpServer(QObject *parent)
    : QObject(parent)
    , m_tcpServer(new QTcpServer(this))
{
    // Set up routes
    m_server.route("/share/<arg>", [this](const QString &shareToken, const QHttpServerRequest &request) {
        return handleShareRequest(request, shareToken);
    });
}

HttpServer::~HttpServer()
{
    stop();
}

bool HttpServer::start(const QString &url, int port)
{
    m_baseUrl = url;

    if (!m_tcpServer->listen(QHostAddress::Any, port)) {
        qCritical() << "Failed to start TCP server:" << m_tcpServer->errorString();
        emit errorOccurred(m_tcpServer->errorString());
        return false;
    }

    if (!m_server.bind(m_tcpServer)) {
        qCritical() << "Failed to bind HTTP server to TCP server";
        emit errorOccurred("Failed to bind HTTP server to TCP server");
        m_tcpServer->close();
        return false;
    }

    // Update the base URL to include the actual port
    QUrl qUrl(m_baseUrl);
    if (qUrl.port() == -1) {
        qUrl.setPort(port);
        m_baseUrl = qUrl.toString();
    }

    qInfo() << "HTTP Server listening on port" << port;
    qInfo() << "Share links will use base URL:" << m_baseUrl;
    qInfo() << "Test URL: " << m_baseUrl << "/share/test";
    emit started();
    return true;
}

void HttpServer::stop()
{
    if (m_tcpServer->isListening()) {
        m_tcpServer->close();
        emit stopped();
    }
}

bool HttpServer::isRunning() const
{
    return m_tcpServer->isListening();
}

QString HttpServer::generateShareLink(const QString &filePath, const QString &baseUrl, const QString &domain)
{
    QString token = registerFileForSharing(filePath);
    if (token.isEmpty()) {
        return QString();
    }

    QString url;

    if (!domain.isEmpty()) {
        url = domain;
        if (!url.endsWith("/")) {
            url += "/";
        }
    } else {
        url = baseUrl;
        if (!url.endsWith("/")) {
            url += "/";
        }
    }

    url += "share/" + token;

    if (domain.isEmpty()) {
        QUrl qUrl(url);
        if (qUrl.port() == -1 && m_tcpServer->isListening()) {
            qUrl.setPort(m_tcpServer->serverPort());
            url = qUrl.toString();
        }
    }

    return url;
}

QString HttpServer::registerFileForSharing(const QString &filePath)
{
    if (filePath.isEmpty()) {
        return QString();
    }

    QString token = generateShareToken();
    m_sharedFiles[token] = filePath;
    return token;
}

QHttpServerResponse HttpServer::handleShareRequest(const QHttpServerRequest &request, const QString &shareToken)
{
    // Check if there's a query parameter for direct download
    QUrl url(QString("http://localhost") + request.url().toString());
    QUrlQuery query(url.query());

    if (query.hasQueryItem("download") && query.queryItemValue("download") == "1") {
        return handleFileDownload(shareToken);
    } else {
        return handleDownloadPage(shareToken);
    }
}

QHttpServerResponse HttpServer::handleDownloadPage(const QString &shareToken)
{
    if (!m_sharedFiles.contains(shareToken)) {
        return QHttpServerResponse("File not found or link expired", QHttpServerResponse::StatusCode::NotFound);
    }

    QString filePath = m_sharedFiles[shareToken];
    QFileInfo fileInfo(filePath);

    if (!fileInfo.exists() || !fileInfo.isFile()) {
        return QHttpServerResponse("File not found", QHttpServerResponse::StatusCode::NotFound);
    }

    QString htmlPage = generateDownloadPage(fileInfo, shareToken);

    // Create headers for the HTML page
    QHttpHeaders headers;
    headers.append(QHttpHeaders::WellKnownHeader::ContentType, "text/html");

    QHttpServerResponse response(htmlPage.toUtf8());
    response.setHeaders(headers);

    return response;
}

QHttpServerResponse HttpServer::handleFileDownload(const QString &shareToken)
{
    if (!m_sharedFiles.contains(shareToken)) {
        return QHttpServerResponse("File not found or link expired", QHttpServerResponse::StatusCode::NotFound);
    }

    QString filePath = m_sharedFiles[shareToken];
    QFileInfo fileInfo(filePath);

    if (!fileInfo.exists() || !fileInfo.isFile()) {
        return QHttpServerResponse("File not found", QHttpServerResponse::StatusCode::NotFound);
    }

    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) {
        return QHttpServerResponse("Error opening file", QHttpServerResponse::StatusCode::InternalServerError);
    }

    QByteArray fileData = file.readAll();
    file.close();

    // Create headers
    QHttpHeaders headers;
    headers.append(QHttpHeaders::WellKnownHeader::ContentDisposition,
                   QString("attachment; filename=\"%1\"").arg(fileInfo.fileName()));

    QMimeDatabase mimeDb;
    QMimeType mimeType = mimeDb.mimeTypeForFile(filePath);
    headers.append(QHttpHeaders::WellKnownHeader::ContentType, mimeType.name());

    // Create response with headers
    QHttpServerResponse response(fileData);
    response.setHeaders(headers);

    return response;
}

QString HttpServer::generateDownloadPage(const QFileInfo &fileInfo, const QString &shareToken)
{
    QString fileName = fileInfo.fileName();
    qint64 fileSize = fileInfo.size();

    // Format file size
    QString sizeStr;
    if (fileSize < 1024) {
        sizeStr = QString("%1 bytes").arg(fileSize);
    } else if (fileSize < 1024 * 1024) {
        sizeStr = QString("%1 KB").arg(fileSize / 1024.0, 0, 'f', 2);
    } else if (fileSize < 1024 * 1024 * 1024) {
        sizeStr = QString("%1 MB").arg(fileSize / (1024.0 * 1024.0), 0, 'f', 2);
    } else {
        sizeStr = QString("%1 GB").arg(fileSize / (1024.0 * 1024.0 * 1024.0), 0, 'f', 2);
    }

    QString html = QString(
                       "<!DOCTYPE html>\n"
                       "<html>\n"
                       "<head>\n"
                       "    <meta charset=\"UTF-8\">\n"
                       "    <title>Download File</title>\n"
                       "    <style>\n"
                       "        body {\n"
                       "            font-family: Arial, sans-serif;\n"
                       "            max-width: 800px;\n"
                       "            margin: 0 auto;\n"
                       "            padding: 20px;\n"
                       "            background-color: #f5f5f5;\n"
                       "        }\n"
                       "        .container {\n"
                       "            background-color: white;\n"
                       "            border-radius: 8px;\n"
                       "            padding: 30px;\n"
                       "            box-shadow: 0 2px 10px rgba(0,0,0,0.1);\n"
                       "        }\n"
                       "        h1 {\n"
                       "            color: #333;\n"
                       "            margin-top: 0;\n"
                       "        }\n"
                       "        .file-info {\n"
                       "            margin: 20px 0;\n"
                       "            padding: 15px;\n"
                       "            background-color: #f9f9f9;\n"
                       "            border-radius: 5px;\n"
                       "        }\n"
                       "        .file-name {\n"
                       "            font-weight: bold;\n"
                       "            font-size: 18px;\n"
                       "            margin-bottom: 10px;\n"
                       "            word-break: break-all;\n"
                       "        }\n"
                       "        .file-size {\n"
                       "            color: #666;\n"
                       "            margin-bottom: 20px;\n"
                       "        }\n"
                       "        .download-btn {\n"
                       "            display: inline-block;\n"
                       "            background-color: #4CAF50;\n"
                       "            color: white;\n"
                       "            padding: 12px 24px;\n"
                       "            text-decoration: none;\n"
                       "            border-radius: 4px;\n"
                       "            font-weight: bold;\n"
                       "            transition: background-color 0.3s;\n"
                       "        }\n"
                       "        .download-btn:hover {\n"
                       "            background-color: #45a049;\n"
                       "        }\n"
                       "        .footer {\n"
                       "            margin-top: 30px;\n"
                       "            text-align: center;\n"
                       "            color: #777;\n"
                       "            font-size: 14px;\n"
                       "        }\n"
                       "    </style>\n"
                       "</head>\n"
                       "<body>\n"
                       "    <div class=\"container\">\n"
                       "        <h1>File Download</h1>\n"
                       "        <div class=\"file-info\">\n"
                       "            <div class=\"file-name\">%1</div>\n"
                       "            <div class=\"file-size\">Size: %2</div>\n"
                       "        </div>\n"
                       "        <a href=\"/share/%3?download=1\" class=\"download-btn\">Download</a>\n"
                       "        <div class=\"footer\">\n"
                       "            <p>This file is shared via OdznDrive</p>\n"
                       "        </div>\n"
                       "    </div>\n"
                       "</body>\n"
                       "</html>"
                       ).arg(fileName, sizeStr, shareToken);

    return html;
}

QString HttpServer::generateShareToken()
{
    return QUuid::createUuid().toString(QUuid::WithoutBraces);
}
