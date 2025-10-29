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
#include <QRandomGenerator>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QFile>

const QRegularExpression HttpServer::s_rangeRegex(R"(bytes=(\d+)-(\d*))");

QString generateRandomToken(int byteLength)
{
    QByteArray randomBytes;
    randomBytes.resize(byteLength);
    QRandomGenerator::global()->fillRange(reinterpret_cast<quint32*>(randomBytes.data()), randomBytes.size() / sizeof(quint32));
    QByteArray base64 = randomBytes.toBase64(QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals);
    return QString::fromUtf8(base64);
}


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
    qInfo() << "Test URL:" << (m_baseUrl + "/share/test");

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

QString HttpServer::generateShareLink(const QString &filePath, const QString &baseUrl, const QString &domain, const bool &shortUrl)
{
    QString token = registerFileForSharing(filePath, shortUrl);
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

QString HttpServer::registerFileForSharing(const QString &filePath, const bool &shortUrl)
{
    if (filePath.isEmpty()) {
        return QString();
    }

    // Check if file is already shared
    QString existingToken = getExistingShareToken(filePath);
    if (!existingToken.isEmpty()) {
        return existingToken;
    }

    QString token = generateShareToken(shortUrl);
    m_sharedFiles[token] = filePath;
    persistShareLinks();
    return token;
}

QHttpServerResponse HttpServer::handleShareRequest(const QHttpServerRequest &request, const QString &shareToken)
{
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
                            qint64 chunkSize = qMin(1024 * 1024LL, remaining);
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
    QFile htmlFile(":/html/download.html");
    if (!htmlFile.open(QIODevice::ReadOnly)) {
        return "<html><body><h1>Error: Could not load download page</h1></body></html>";
    }

    QString htmlContent = QTextStream(&htmlFile).readAll();
    htmlFile.close();

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

    QString fileTypeIconPath = getFileTypeIcon(fileInfo.fileName());
    QString fileTypeIconBase64;
    QFile fileTypeIconFile(fileTypeIconPath);
    if (fileTypeIconFile.open(QIODevice::ReadOnly)) {
        QByteArray iconData = fileTypeIconFile.readAll();
        fileTypeIconFile.close();
        fileTypeIconBase64 = QString::fromLatin1(iconData.toBase64());
    }

    htmlContent.replace("{{FILE_NAME}}", fileInfo.fileName());
    htmlContent.replace("{{FILE_SIZE}}", sizeStr);
    htmlContent.replace("{{DOWNLOAD_URL}}", QString("/share/%1?download=1").arg(shareToken));
    htmlContent.replace("{{ICON_URL}}", "data:image/png;base64," + iconBase64);
    htmlContent.replace("{{FAVICON_URL}}", "data:image/x-icon;base64," + faviconBase64);
    htmlContent.replace("{{FILE_TYPE_IMAGE_URL}}", "data:image/svg+xml;base64," + fileTypeIconBase64);

    return htmlContent;
}

QString HttpServer::getFileTypeIcon(const QString &fileName)
{
    if (fileName.isEmpty())
        return ":/icons/types/unknow.svg";

    QString ext = fileName.section('.', -1).toLower();

    QStringList codeExt = {"c", "cpp", "cxx", "h", "hpp", "hxx", "cs", "java", "js", "ts", "py", "rb", "php", "go", "rs", "swift", "kt", "sh", "bat", "ps1", "html", "css", "scss"};
    QStringList wordExt = {"doc", "docx", "odt", "rtf"};
    QStringList excelExt = {"xls", "xlsx", "ods", "csv"};
    QStringList pptExt = {"ppt", "pptx", "odp"};
    QStringList pdfExt = {"pdf"};
    QStringList textExt = {"txt", "md", "ini", "cfg", "json", "xml", "yml", "yaml", "log"};
    QStringList picExt = {"png", "jpg", "jpeg", "gif", "bmp", "svg", "webp", "tif", "tiff"};
    QStringList audioExt = {"mp3", "wav", "flac", "aac", "ogg", "m4a", "wma"};
    QStringList videoExt = {"mp4", "avi", "mkv", "mov", "wmv", "flv", "webm"};
    QStringList zipExt = {"zip", "rar", "7z", "tar", "gz", "bz2"};

    if (codeExt.contains(ext)) return ":/icons/types/code.svg";
    if (wordExt.contains(ext)) return ":/icons/types/word.svg";
    if (excelExt.contains(ext)) return ":/icons/types/excel.svg";
    if (pptExt.contains(ext)) return ":/icons/types/powerpoint.svg";
    if (pdfExt.contains(ext)) return ":/icons/types/pdf.svg";
    if (textExt.contains(ext)) return ":/icons/types/text.svg";
    if (picExt.contains(ext)) return ":/icons/types/picture.svg";
    if (audioExt.contains(ext)) return ":/icons/types/audio.svg";
    if (videoExt.contains(ext)) return ":/icons/types/video.svg";
    if (zipExt.contains(ext)) return ":/icons/types/zip.svg";

    return ":/icons/types/unknow.svg";
}

QHttpServerResponse HttpServer::handleDownloadPage(const QString &shareToken)
{
    if (!m_sharedFiles.contains(shareToken)) {
        QFile htmlFile(":/html/error.html");
        if (!htmlFile.open(QIODevice::ReadOnly)) {
            return QHttpServerResponse("Error page not found", QHttpServerResponse::StatusCode::NotFound);
        }

        QString htmlContent = QTextStream(&htmlFile).readAll();
        htmlFile.close();

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

        htmlContent.replace("{{ERROR_MESSAGE}}", "File not found or link expired");
        htmlContent.replace("{{ICON_URL}}", "data:image/png;base64," + iconBase64);
        htmlContent.replace("{{FAVICON_URL}}", "data:image/x-icon;base64," + faviconBase64);

        QHttpHeaders headers;
        headers.append(QHttpHeaders::WellKnownHeader::ContentType, "text/html");

        QHttpServerResponse response(htmlContent.toUtf8());
        response.setHeaders(headers);

        return response;
    }

    QString filePath = m_sharedFiles[shareToken];
    QFileInfo fileInfo(filePath);

    if (!fileInfo.exists() || !fileInfo.isFile()) {
        QFile htmlFile(":/html/error.html");
        if (!htmlFile.open(QIODevice::ReadOnly)) {
            return QHttpServerResponse("Error page not found", QHttpServerResponse::StatusCode::NotFound);
        }

        QString htmlContent = QTextStream(&htmlFile).readAll();
        htmlFile.close();

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

        htmlContent.replace("{{ERROR_MESSAGE}}", "File not found");
        htmlContent.replace("{{ICON_URL}}", "data:image/png;base64," + iconBase64);
        htmlContent.replace("{{FAVICON_URL}}", "data:image/x-icon;base64," + faviconBase64);

        QHttpHeaders headers;
        headers.append(QHttpHeaders::WellKnownHeader::ContentType, "text/html");

        QHttpServerResponse response(htmlContent.toUtf8());
        response.setHeaders(headers);

        return response;
    }

    QString htmlPage = generateDownloadPage(fileInfo, shareToken);

    QHttpHeaders headers;
    headers.append(QHttpHeaders::WellKnownHeader::ContentType, "text/html");

    QHttpServerResponse response(htmlPage.toUtf8());
    response.setHeaders(headers);

    return response;
}

QString HttpServer::generateShareToken(const bool &shortUrl)
{
    if (shortUrl) {
        return generateRandomToken(9);
    }

    return QUuid::createUuid().toString(QUuid::WithoutBraces);
}

QString HttpServer::getExistingShareToken(const QString &filePath) const
{
    for (auto it = m_sharedFiles.begin(); it != m_sharedFiles.end(); ++it) {
        if (it.value() == filePath) {
            return it.key();
        }
    }
    return QString();
}

void HttpServer::loadShareLinksFromFile(const QString &filePath)
{
    m_shareLinksFilePath = filePath;

    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) {
        qWarning() << "Could not open share links file:" << filePath;
        return;
    }

    QByteArray data = file.readAll();
    file.close();

    QJsonDocument doc = QJsonDocument::fromJson(data);
    if (!doc.isObject()) {
        qWarning() << "Invalid share links JSON format";
        return;
    }

    QJsonObject root = doc.object();
    QJsonArray shareLinks = root.value("shareLinks").toArray();

    for (const QJsonValue &value : shareLinks) {
        QJsonObject linkObj = value.toObject();
        QString token = linkObj.value("token").toString();
        QString path = linkObj.value("path").toString();

        if (!token.isEmpty() && !path.isEmpty()) {
            // Verify the file still exists before loading
            QFileInfo fileInfo(path);
            if (fileInfo.exists() && fileInfo.isFile()) {
                m_sharedFiles[token] = path;
            } else {
                qWarning() << "Shared file no longer exists, skipping:" << path;
            }
        }
    }

    qInfo() << "Loaded" << m_sharedFiles.size() << "share links from file";
}

void HttpServer::saveShareLinksToFile(const QString &filePath) const
{
    QJsonArray shareLinksArray;

    for (auto it = m_sharedFiles.begin(); it != m_sharedFiles.end(); ++it) {
        QJsonObject linkObj;
        linkObj.insert("token", it.key());
        linkObj.insert("path", it.value());
        shareLinksArray.append(linkObj);
    }

    QJsonObject root;
    root.insert("shareLinks", shareLinksArray);

    QJsonDocument doc(root);
    QFile file(filePath);
    if (!file.open(QIODevice::WriteOnly)) {
        qWarning() << "Could not open share links file for writing:" << filePath;
        return;
    }

    file.write(doc.toJson());
    file.close();

    qDebug() << "Share links saved to file:" << filePath;
}

void HttpServer::updateFilePathInShareLinks(const QString &oldPath, const QString &newPath)
{
    QString token = getExistingShareToken(oldPath);
    if (!token.isEmpty()) {
        m_sharedFiles[token] = newPath;
        qInfo() << "Updated share link path from" << oldPath << "to" << newPath;
        persistShareLinks();
    }
}

void HttpServer::removeShareLink(const QString &filePath)
{
    QString token = getExistingShareToken(filePath);
    if (!token.isEmpty()) {
        m_sharedFiles.remove(token);
        qInfo() << "Removed share link for" << filePath;
        persistShareLinks();
    }
}

void HttpServer::removeShareLinksInDirectory(const QString &dirPath)
{
    QStringList tokensToRemove;

    // Find all share links that start with the directory path
    for (auto it = m_sharedFiles.begin(); it != m_sharedFiles.end(); ++it) {
        if (it.value().startsWith(dirPath + "/") || it.value().startsWith(dirPath + "\\")) {
            tokensToRemove.append(it.key());
        }
    }

    // Remove the found share links
    for (const QString &token : tokensToRemove) {
        QString removedPath = m_sharedFiles[token];
        m_sharedFiles.remove(token);
        qInfo() << "Removed share link for" << removedPath << "(in deleted directory)";
    }

    persistShareLinks();
}

void HttpServer::persistShareLinks() const
{
    if (!m_shareLinksFilePath.isEmpty()) {
        saveShareLinksToFile(m_shareLinksFilePath);
    }
}
