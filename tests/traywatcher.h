// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include <QDBusContext>
#include <QDBusMessage>
#include <QObject>
#include <QRect>
#include <QDebug>
#include <QStringList>

// A minimal watcher on the isolated test bus, never the user's desktop bus.
class TrayWatcherFixture : public QObject, protected QDBusContext
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.kde.StatusNotifierWatcher")
    Q_PROPERTY(QStringList RegisteredStatusNotifierItems READ items)
    Q_PROPERTY(bool IsStatusNotifierHostRegistered READ hostRegistered)
    Q_PROPERTY(int ProtocolVersion READ protocolVersion)
public:
    using QObject::QObject;
    QStringList items() const { return m_items; }
    bool hostRegistered() const { return true; }
    int protocolVersion() const { return 0; }
public Q_SLOTS:
    void RegisterStatusNotifierItem(const QString &service)
    {
        QString item = service;
        if (service.startsWith(QLatin1Char('/'))) item.prepend(message().service());
        else item.append(QStringLiteral("/StatusNotifierItem"));
        if (m_items.contains(item)) return;
        m_items.append(item);
        Q_EMIT StatusNotifierItemRegistered(item);
    }
    void RegisterStatusNotifierHost(const QString &) { Q_EMIT StatusNotifierHostRegistered(); }
Q_SIGNALS:
    void StatusNotifierItemRegistered(const QString &item);
    void StatusNotifierItemUnregistered(const QString &item);
    void StatusNotifierHostRegistered();
    void StatusNotifierHostUnregistered();
private:
    QStringList m_items;
};

// Wayland clients do not reliably receive global window coordinates. Ask the
// isolated KWin instance for the actual compositor geometry instead.
class GeometryProbe : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.eirom.ControlHubSmoke.Geometry")
public:
    using QObject::QObject;
    QRect geometry;
    bool ready = false;
public Q_SLOTS:
    void report(int x, int y, int width, int height) { record(x, y, width, height); }
    void report(double x, double y, double width, double height) { record(qRound(x), qRound(y), qRound(width), qRound(height)); }
private:
    void record(int x, int y, int width, int height) {
        qInfo() << "KWin compositor window:" << QRect(x, y, width, height);
        if (height > geometry.height()) geometry = QRect(x, y, width, height);
        ready = true;
    }
};
