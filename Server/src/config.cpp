#include "config.h"
#include <QDir>
#include <QStandardPaths>
#include <QCoreApplication>

Config::Config()
    : m_settings(QCoreApplication::organizationName(), QCoreApplication::applicationName())
{
}

Config& Config::instance()
{
    static Config instance;
    return instance;
}

void Config::load()
{
    m_port = m_settings.value("server/port", 8888).toInt();
    
    QString defaultStorage = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/storage";
    m_storageRoot = m_settings.value("server/storage_root", defaultStorage).toString();
    
    m_storageLimit = m_settings.value("server/storage_limit", 10737418240LL).toLongLong(); // 10GB default
    m_password = m_settings.value("server/password", "admin123").toString();
    
    QDir().mkpath(m_storageRoot);
}

void Config::save()
{
    m_settings.setValue("server/port", m_port);
    m_settings.setValue("server/storage_root", m_storageRoot);
    m_settings.setValue("server/storage_limit", m_storageLimit);
    m_settings.setValue("server/password", m_password);
    m_settings.sync();
}