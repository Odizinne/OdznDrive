#ifndef HTTPSERVER_H
#define HTTPSERVER_H

#include <QObject>
#include <QHttpServer>
#include <QHttpServerResponse>
#include <QHttpServerRequest>
#include <QHash>
#include <QFileInfo>
#include <QTcpServer>

class HttpServer : public QObject
{
    Q_OBJECT

public:
    explicit HttpServer(QObject *parent = nullptr);
    ~HttpServer();

    bool start(const QString &url, int port);
    void stop();
    bool isRunning() const;

    // Generate a share link for a file
    QString generateShareLink(const QString &filePath, const QString &baseUrl, const QString &domain);

    // Register a file with a share token
    QString registerFileForSharing(const QString &filePath);

signals:
    void started();
    void stopped();
    void errorOccurred(const QString &error);

private:
    QHttpServerResponse handleShareRequest(const QHttpServerRequest &request, const QString &shareToken);
    QHttpServerResponse handleDownloadPage(const QString &shareToken);
    QHttpServerResponse handleFileDownload(const QString &shareToken);
    QString generateDownloadPage(const QFileInfo &fileInfo, const QString &shareToken);
    QString generateShareToken();

    QHttpServer m_server;
    QTcpServer *m_tcpServer;
    QHash<QString, QString> m_sharedFiles; // token -> file path
    QString m_baseUrl;
};

#endif // HTTPSERVER_H
