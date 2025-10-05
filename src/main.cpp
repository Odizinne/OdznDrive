#include <QApplication>
#include <QQmlApplicationEngine>
#include <QIcon>
#include <QFontDatabase>
#include "imagepreviewprovider.h"
#include "connectionmanager.h"

int main(int argc, char *argv[])
{
    qputenv("QT_QUICK_CONTROLS_MATERIAL_VARIANT", "Dense");
    QApplication app(argc, argv);

    qint32 fontId = QFontDatabase::addApplicationFont(":/fonts/RobotoMono-Regular.ttf");
    QStringList fontList = QFontDatabase::applicationFontFamilies(fontId);
    QString family = fontList.first();

    QApplication::setOrganizationName("Odizinne");
    QApplication::setApplicationName("OdznDrive");
    QApplication::setWindowIcon(QIcon(":/icons/icon.png"));
    QApplication::setFont(QFont(family));

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
