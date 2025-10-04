#ifndef IMAGEPREVIEWPROVIDER_H
#define IMAGEPREVIEWPROVIDER_H

#include <QQuickImageProvider>
#include <QHash>
#include <QMutex>
#include <QImage>

class ImagePreviewProvider : public QQuickImageProvider
{
public:
    ImagePreviewProvider();

    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize) override;

    void addImage(const QString &path, const QImage &image);
    void clear();
    bool hasImage(const QString &path) const;

private:
    QHash<QString, QImage> m_cache;
    mutable QMutex m_mutex;
};

#endif // IMAGEPREVIEWPROVIDER_H
