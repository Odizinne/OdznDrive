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
#include <QHttpServerRequest>
#include <QHttpServerResponder>
#include <QSettings>
#include <QTemporaryFile>

const QRegularExpression HttpServer::s_rangeRegex(R"(bytes=(\d+)-(\d*))");


HttpServer::HttpServer(QObject *parent)
    : QObject(parent)
    , m_tcpServer(new QTcpServer(this))
{
    m_server.route("/share/<arg>", [this](const QString &shareToken, const QHttpServerRequest &request) {
        return handleShareRequest(request, shareToken);
    });

    m_server.route("/", []() {
        return QHttpServerResponse("OdznDrive HTTP Server is running!");
    });

    m_server.route("/test", []() {
        return QHttpServerResponse("HTTP Server is working!");
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
        return handleFileDownload(shareToken, request);
    } else {
        return handleDownloadPage(shareToken);
    }
}

QHttpServerResponse HttpServer::handleFileDownload(const QString &shareToken, const QHttpServerRequest &request)
{
    if (!m_sharedFiles.contains(shareToken)) {
        return QHttpServerResponse("File not found", QHttpServerResponse::StatusCode::NotFound);
    }

    QString filePath = m_sharedFiles[shareToken];
    QFileInfo fileInfo(filePath);

    if (!fileInfo.exists() || !fileInfo.isFile()) {
        return QHttpServerResponse("File not found", QHttpServerResponse::StatusCode::NotFound);
    }

    qint64 fileSize = fileInfo.size();

    // Check for Range header
    const QHttpHeaders headers = request.headers();
    const QByteArrayView rangeHeaderView = headers.value(QHttpHeaders::WellKnownHeader::Range);

    if (!rangeHeaderView.isEmpty()) {
        QByteArray rangeHeader = QByteArray(rangeHeaderView);
        QString rangeValue = QString::fromUtf8(rangeHeader);
        QRegularExpressionMatch match = s_rangeRegex.match(rangeValue);

        if (match.hasMatch()) {
            qint64 start = match.captured(1).toLongLong();
            qint64 end = match.captured(2).isEmpty() ? fileSize - 1 : match.captured(2).toLongLong();

            if (start >= 0 && start < fileSize && end >= start && end < fileSize) {
                qint64 contentLength = end - start + 1;

                QTemporaryFile tempFile;
                if (tempFile.open()) {
                    QFile sourceFile(filePath);
                    if (sourceFile.open(QIODevice::ReadOnly)) {
                        sourceFile.seek(start);

                        qint64 remaining = contentLength;
                        while (remaining > 0) {
                            qint64 chunkSize = qMin(1024 * 1024LL, remaining); // 1MB chunks
                            QByteArray chunk = sourceFile.read(chunkSize);
                            if (chunk.isEmpty()) {
                                break;
                            }
                            tempFile.write(chunk);
                            remaining -= chunk.size();
                        }
                        sourceFile.close();
                        tempFile.close();

                        QHttpServerResponse fileResponse = QHttpServerResponse::fromFile(tempFile.fileName());
                        QHttpHeaders fileResponseHeaders;
                        fileResponseHeaders.append(QHttpHeaders::WellKnownHeader::ContentRange,
                                                   QString("bytes %1-%2/%3").arg(start).arg(end).arg(fileSize).toUtf8());
                        fileResponseHeaders.append(QHttpHeaders::WellKnownHeader::ContentType,
                                                   QMimeDatabase().mimeTypeForFile(filePath).name().toUtf8());
                        fileResponseHeaders.append(QHttpHeaders::WellKnownHeader::AcceptRanges, "bytes");
                        fileResponseHeaders.append(QHttpHeaders::WellKnownHeader::ContentDisposition,
                                                   QString("attachment; filename=\"%1\"").arg(fileInfo.fileName()).toUtf8());

                        fileResponse.setHeaders(fileResponseHeaders);
                        return fileResponse;
                    }
                }
            }
        }
    }

    QHttpServerResponse response = QHttpServerResponse::fromFile(filePath);

    QHttpHeaders responseHeaders;
    responseHeaders.append(QHttpHeaders::WellKnownHeader::ContentType,
                           QMimeDatabase().mimeTypeForFile(filePath).name().toUtf8());
    responseHeaders.append(QHttpHeaders::WellKnownHeader::ContentDisposition,
                           QString("attachment; filename=\"%1\"").arg(fileInfo.fileName()).toUtf8());
    responseHeaders.append(QHttpHeaders::WellKnownHeader::AcceptRanges, "bytes");

    response.setHeaders(responseHeaders);

    return response;
}

QString HttpServer::generateDownloadPage(const QFileInfo &fileInfo, const QString &shareToken)
{
    // Load HTML template from resources
    QFile htmlFile(":/html/download.html");
    if (!htmlFile.open(QIODevice::ReadOnly)) {
        return "<html><body><h1>Error: Could not load download page</h1></body></html>";
    }

    QString htmlContent = QTextStream(&htmlFile).readAll();
    htmlFile.close();

    // Format file size
    qint64 fileSize = fileInfo.size();
    QString sizeStr;
    if (fileSize < 1024) {
        sizeStr = QString("%1 bytes").arg(fileSize);
    } else if (fileSize < 1024 * 1024) {
        sizeStr = QString("%1 KB").arg(fileSize / 1024.0, 0, 'f', 1);
    } else if (fileSize < 1024 * 1024 * 1024) {
        sizeStr = QString("%1 MB").arg(fileSize / (1024.0 * 1024.0), 0, 'f', 1);
    } else {
        sizeStr = QString("%1 GB").arg(fileSize / (1024.0 * 1024.0 * 1024.0), 0, 'f', 1);
    }

    // Get base64 encoded icons
    QString iconBase64;
    QFile iconFile(":/icons/icon.png");
    if (iconFile.open(QIODevice::ReadOnly)) {
        QByteArray iconData = iconFile.readAll();
        iconFile.close();
        iconBase64 = QString::fromLatin1(iconData.toBase64());
    }

    QString faviconBase64;
    QFile faviconFile(":/icons/favicon.ico");
    if (faviconFile.open(QIODevice::ReadOnly)) {
        QByteArray faviconData = faviconFile.readAll();
        faviconFile.close();
        faviconBase64 = QString::fromLatin1(faviconData.toBase64());
    }

    // Replace placeholders in HTML
    htmlContent.replace("{{FILE_NAME}}", fileInfo.fileName());
    htmlContent.replace("{{FILE_SIZE}}", sizeStr);
    htmlContent.replace("{{DOWNLOAD_URL}}", QString("/share/%1?download=1").arg(shareToken));
    htmlContent.replace("{{ICON_URL}}", "data:image/png;base64," + iconBase64);
    htmlContent.replace("{{FAVICON_URL}}", "data:image/x-icon;base64," + faviconBase64);

    return htmlContent;
}

QHttpServerResponse HttpServer::handleDownloadPage(const QString &shareToken)
{
    if (!m_sharedFiles.contains(shareToken)) {
        // Load error HTML template from resources
        QFile htmlFile(":/html/error.html");
        if (!htmlFile.open(QIODevice::ReadOnly)) {
            return QHttpServerResponse("Error page not found", QHttpServerResponse::StatusCode::NotFound);
        }

        QString htmlContent = QTextStream(&htmlFile).readAll();
        htmlFile.close();

        // Get base64 encoded icons
        QString iconBase64;
        QFile iconFile(":/icons/icon.png");
        if (iconFile.open(QIODevice::ReadOnly)) {
            QByteArray iconData = iconFile.readAll();
            iconFile.close();
            iconBase64 = QString::fromLatin1(iconData.toBase64());
        }

        QString faviconBase64;
        QFile faviconFile(":/icons/favicon.ico");
        if (faviconFile.open(QIODevice::ReadOnly)) {
            QByteArray faviconData = faviconFile.readAll();
            faviconFile.close();
            faviconBase64 = QString::fromLatin1(faviconData.toBase64());
        }

        // Replace placeholders
        htmlContent.replace("{{ERROR_MESSAGE}}", "File not found or link expired");
        htmlContent.replace("{{ICON_URL}}", "data:image/png;base64," + iconBase64);
        htmlContent.replace("{{FAVICON_URL}}", "data:image/x-icon;base64," + faviconBase64);

        // Create headers for the HTML page
        QHttpHeaders headers;
        headers.append(QHttpHeaders::WellKnownHeader::ContentType, "text/html");

        QHttpServerResponse response(htmlContent.toUtf8());
        response.setHeaders(headers);

        return response;
    }

    QString filePath = m_sharedFiles[shareToken];
    QFileInfo fileInfo(filePath);

    if (!fileInfo.exists() || !fileInfo.isFile()) {
        // Load error HTML template from resources
        QFile htmlFile(":/html/error.html");
        if (!htmlFile.open(QIODevice::ReadOnly)) {
            return QHttpServerResponse("Error page not found", QHttpServerResponse::StatusCode::NotFound);
        }

        QString htmlContent = QTextStream(&htmlFile).readAll();
        htmlFile.close();

        // Get base64 encoded icons
        QString iconBase64;
        QFile iconFile(":/icons/icon.png");
        if (iconFile.open(QIODevice::ReadOnly)) {
            QByteArray iconData = iconFile.readAll();
            iconFile.close();
            iconBase64 = QString::fromLatin1(iconData.toBase64());
        }

        QString faviconBase64;
        QFile faviconFile(":/icons/favicon.ico");
        if (faviconFile.open(QIODevice::ReadOnly)) {
            QByteArray faviconData = faviconFile.readAll();
            faviconFile.close();
            faviconBase64 = QString::fromLatin1(faviconData.toBase64());
        }

        // Replace placeholders
        htmlContent.replace("{{ERROR_MESSAGE}}", "File not found");
        htmlContent.replace("{{ICON_URL}}", "data:image/png;base64," + iconBase64);
        htmlContent.replace("{{FAVICON_URL}}", "data:image/x-icon;base64," + faviconBase64);

        // Create headers for the HTML page
        QHttpHeaders headers;
        headers.append(QHttpHeaders::WellKnownHeader::ContentType, "text/html");

        QHttpServerResponse response(htmlContent.toUtf8());
        response.setHeaders(headers);

        return response;
    }

    QString htmlPage = generateDownloadPage(fileInfo, shareToken);

    // Create headers for the HTML page
    QHttpHeaders headers;
    headers.append(QHttpHeaders::WellKnownHeader::ContentType, "text/html");

    QHttpServerResponse response(htmlPage.toUtf8());
    response.setHeaders(headers);

    return response;
}

QString HttpServer::generateShareToken()
{
    return QUuid::createUuid().toString(QUuid::WithoutBraces);
}
