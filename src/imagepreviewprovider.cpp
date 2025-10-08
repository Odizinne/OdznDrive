#include "imagepreviewprovider.h"
#include <QDebug>

ImagePreviewProvider::ImagePreviewProvider()
    : QQuickImageProvider(QQuickImageProvider::Image)
{
}

QImage ImagePreviewProvider::requestImage(const QString &id, QSize *size, const QSize &requestedSize)
{
    QMutexLocker locker(&m_mutex);

    if (m_cache.contains(id)) {
        QImage img = m_cache.value(id);

        if (size) {
            *size = img.size();
        }

        if (requestedSize.isValid() && !requestedSize.isEmpty()) {
            return img.scaled(requestedSize, Qt::KeepAspectRatio, Qt::SmoothTransformation);
        }

        return img;
    }

    QImage placeholder(64, 64, QImage::Format_ARGB32);
    placeholder.fill(Qt::transparent);

    if (size) {
        *size = placeholder.size();
    }

    return placeholder;
}

void ImagePreviewProvider::addImage(const QString &path, const QImage &image)
{
    QMutexLocker locker(&m_mutex);
    m_cache.insert(path, image);
}

void ImagePreviewProvider::clear()
{
    QMutexLocker locker(&m_mutex);
    m_cache.clear();
}

bool ImagePreviewProvider::hasImage(const QString &path) const
{
    QMutexLocker locker(&m_mutex);
    return m_cache.contains(path);
}
