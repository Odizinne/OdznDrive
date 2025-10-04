#include <QApplication>
#include <QQmlApplicationEngine>
#include <QIcon>
#include "imagepreviewprovider.h"
#include "connectionmanager.h"

int main(int argc, char *argv[])
{
    qputenv("QT_QUICK_CONTROLS_MATERIAL_VARIANT", "Dense");
    QApplication app(argc, argv);

    QApplication::setOrganizationName("Odizinne");
    QApplication::setApplicationName("OdznDrive");
    QApplication::setWindowIcon(QIcon(":/icons/icon.png"));

    QQmlApplicationEngine engine;

    // Create and register image provider
    ImagePreviewProvider *imageProvider = new ImagePreviewProvider();
    engine.addImageProvider("preview", imageProvider);

    // Set the provider in ConnectionManager
    ConnectionManager::instance()->setImageProvider(imageProvider);

    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
                     &app, []() { QCoreApplication::exit(-1); },
                     Qt::QueuedConnection);

    engine.loadFromModule("Odizinne.OdznDrive", "Main");

    return app.exec();
}
