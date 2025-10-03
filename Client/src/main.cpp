#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QIcon>

int main(int argc, char *argv[])
{
    qputenv("QT_QUICK_CONTROLS_MATERIAL_VARIANT", "Dense");
    QGuiApplication app(argc, argv);
    
    QGuiApplication::setOrganizationName("Odizinne");
    QGuiApplication::setApplicationName("OdznDriveClient");
    QGuiApplication::setApplicationVersion("1.0.0");
    
    QQmlApplicationEngine engine;
    
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
                     &app, []() { QCoreApplication::exit(-1); },
                     Qt::QueuedConnection);
    
    engine.loadFromModule("Odizinne.OdznDriveClient", "Main");
    
    return app.exec();
}
