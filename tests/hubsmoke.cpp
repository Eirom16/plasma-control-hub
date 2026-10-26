// SPDX-FileCopyrightText: 2026 Eirom16
// SPDX-License-Identifier: GPL-2.0-or-later
#include <QApplication>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusConnectionInterface>
#include <QDBusError>
#include <QDBusInterface>
#include <QDBusReply>
#include <QTemporaryFile>
#include <QProcess>
#include <KStatusNotifierItem>
#include <notificationmanager/server.h>
#include "traywatcher.h"
#include <QDBusPendingCall>
#include <QDBusPendingReply>
#include <QDir>
#include <QFile>
#include <QImage>
#include <QJSValue>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QQuickWindow>
#include <QScreen>
#include <QSet>
#include <QSortFilterProxyModel>
#include <QTemporaryDir>
#include <QTest>
#include <QTimer>
#include <KConfigLoader>
#include <KLocalizedString>
#include <KPackage/PackageLoader>
#include <Plasma/Corona>
#include <Plasma/Containment>
#include <PlasmaQuick/AppletQuickItem>
#include <cstdio>
#include <memory>

static bool invalidQml = false;
static void logMessage(QtMsgType, const QMessageLogContext &, const QString &message)
{
    if (message.contains(QStringLiteral("plasma/applet/org/eirom/plasma/controlhub"))
        && (message.contains(QStringLiteral("TypeError")) || message.contains(QStringLiteral("ReferenceError"))
            || message.contains(QStringLiteral("Binding loop")) || message.contains(QStringLiteral("Cannot assign")))) {
        invalidQml = true;
    }
    std::fprintf(stderr, "%s\n", qPrintable(message));
}

class TestCorona : public Plasma::Corona
{
public:
    QRect screenGeometry(uint) const override { return QGuiApplication::primaryScreen()->availableGeometry(); }
};

static QQuickWindow *windowNamed(const QString &name)
{
    for (auto *window : QGuiApplication::allWindows()) {
        if (window->objectName() == name) return qobject_cast<QQuickWindow *>(window);
    }
    return nullptr;
}
static QQuickItem *visualChild(QQuickItem *parent, const QString &name)
{
    if (parent->objectName() == name) return parent;
    for (auto *child : parent->childItems()) {
        if (auto *result = visualChild(child, name)) return result;
    }
    return nullptr;
}
static void capture(QQuickWindow *window, const QString &name)
{
    const QString output = qEnvironmentVariable("CONTROLHUB_SCREENSHOTS");
    if (!window || output.isEmpty()) return;
    QDir().mkpath(output);
    window->grabWindow().save(output + QLatin1Char('/') + name + QStringLiteral(".png"));
}

static bool drivePointer(const QPoint &source, const QPoint &target, qreal scale)
{
    QProcess pointer;
    auto environment = QProcessEnvironment::systemEnvironment();
    environment.insert(QStringLiteral("CONTROLHUB_POINTER_TEST"), QStringLiteral("1"));
    pointer.setProcessEnvironment(environment);
    pointer.start(QStringLiteral("python3"), {QStringLiteral(CONTROLHUB_TEST_DIR "/drag-x11.py"), QString::number(qRound(source.x() * scale)), QString::number(qRound(source.y() * scale)), QString::number(qRound(target.x() * scale)), QString::number(qRound(target.y() * scale))});
    QTest::qWait(1200);
    if ((pointer.state() != QProcess::NotRunning && !pointer.waitForFinished(1000)) || pointer.exitCode() != 0) {
        qCritical() << pointer.readAllStandardError();
        return false;
    }
    return true;
}

int main(int argc, char **argv)
{
    QTemporaryDir config;
    if (!config.isValid()) return 2;
    for (const auto &kind : {"CONFIG", "DATA", "CACHE", "STATE"}) {
        const QByteArray variable = QByteArray("XDG_") + kind + "_HOME";
        qputenv(variable.constData(), (config.path() + QLatin1Char('/') + QString::fromLatin1(kind).toLower()).toUtf8());
    }
    if (qEnvironmentVariableIsEmpty("XDG_RUNTIME_DIR")) {
        const auto runtime = config.path() + QStringLiteral("/runtime");
        QDir().mkpath(runtime);
        QFile::setPermissions(runtime, QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner);
        qputenv("XDG_RUNTIME_DIR", runtime.toUtf8());
    }
    // A real desktop identity keeps the fixture out of KDE's default @other
    // history blacklist, including on CI machines without Konsole installed.
    const auto applications = qEnvironmentVariable("XDG_DATA_HOME") + QStringLiteral("/applications");
    QDir().mkpath(applications);
    QFile identity(applications + QStringLiteral("/org.eirom.ControlHubSmoke.desktop"));
    if (!identity.open(QIODevice::WriteOnly)) return 2;
    identity.write("[Desktop Entry]\nType=Application\nName=Control Hub\nExec=/bin/true\nIcon=dialog-information\n");
    identity.close();
    const QString reviewConfig = qEnvironmentVariable("CONTROLHUB_REVIEW_CONFIG");
    if (!reviewConfig.isEmpty()) {
        const QString configHome = qEnvironmentVariable("XDG_CONFIG_HOME");
        QDir().mkpath(configHome);
        if (!QFile::copy(reviewConfig, configHome + QStringLiteral("/kdeglobals"))) return 2;
    }
    QApplication app(argc, argv);
    qInstallMessageHandler(logMessage);
    app.setApplicationName(QStringLiteral("controlhub-smoke"));
    app.setQuitOnLastWindowClosed(false);
    KLocalizedString::setApplicationDomain("plasma_applet_org.eirom.plasma.controlhub");
    GeometryProbe geometryProbe;
    QDBusConnection::sessionBus().registerService(QStringLiteral("org.eirom.ControlHubSmoke"));
    QDBusConnection::sessionBus().registerObject(QStringLiteral("/GeometryProbe"), &geometryProbe, QDBusConnection::ExportAllSlots);
    TrayWatcherFixture watcher;
    QDBusConnection::sessionBus().registerService(QStringLiteral("org.kde.StatusNotifierWatcher"));
    QDBusConnection::sessionBus().registerObject(QStringLiteral("/StatusNotifierWatcher"), &watcher, QDBusConnection::ExportAllContents);
    KStatusNotifierItem testIcon(QStringLiteral("controlhub-fixture"), &app);
    testIcon.setTitle(QStringLiteral("Control Hub test application"));
    testIcon.setIconByName(QStringLiteral("applications-system"));
    testIcon.setStatus(KStatusNotifierItem::Active);
    NotificationManager::Server::self().init();
    TestCorona corona;
    auto shell = KPackage::PackageLoader::self()->loadPackage(QStringLiteral("Plasma/Shell"));
    shell.setPath(QStringLiteral("org.kde.plasma.desktop"));
    corona.setKPackage(shell);
    auto *parentPanel = corona.createContainment(QStringLiteral("org.kde.panel"));
    if (!parentPanel) return 3;
    parentPanel->setFormFactor(Plasma::Types::Horizontal);
    parentPanel->setLocation(Plasma::Types::BottomEdge);
    auto *containment = qobject_cast<Plasma::Containment *>(parentPanel->createApplet(QStringLiteral("org.eirom.plasma.controlhub")));
    if (!containment || !containment->pluginMetaData().isValid()) return 3;
    containment->setFormFactor(Plasma::Types::Horizontal);
    containment->setLocation(Plasma::Types::BottomEdge);
    auto *item = PlasmaQuick::AppletQuickItem::itemForApplet(containment);
    if (!item) return 4;
    QQuickWindow panel;
    panel.setColor(app.palette().color(QPalette::Window));
    panel.setObjectName(QStringLiteral("reviewPanel"));
    panel.resize(360, 48);
    item->setParentItem(panel.contentItem());
    item->setSize(panel.size());
    panel.show();

    QTimer::singleShot(2500, &app, [&]() {
        const auto entries = item->property("controlEntries").value<QJSValue>().toVariant().toList();
        QSet<QString> ids;
        for (const auto &entry : entries) {
            const auto id = entry.toMap().value(QStringLiteral("id")).toString();
            if (id.isEmpty() || ids.contains(id)) { app.exit(5); return; }
            ids.insert(id);
        }
        qInfo() << "Loaded control modules:" << ids;
        if (entries.isEmpty()) { app.exit(5); return; }
        // Exercise the actual layout at panel sizes rather than just checking
        // constants: buttons must share cells, centers and valid bundled glyphs.
        auto *expandButton = visualChild(item, QStringLiteral("expanderButton"));
        auto *controlsButton = visualChild(item, QStringLiteral("controlsButton"));
        auto *notificationsButton = visualChild(item, QStringLiteral("notificationsButton"));
        if (!expandButton || !controlsButton || !notificationsButton) { app.exit(25); return; }
        for (const bool vertical : {false, true}) {
            parentPanel->setFormFactor(vertical ? Plasma::Types::Vertical : Plasma::Types::Horizontal);
            parentPanel->setLocation(vertical ? Plasma::Types::RightEdge : Plasma::Types::BottomEdge);
            for (const int thickness : {24, 40, 64}) {
                const QSize size = vertical ? QSize(thickness, 360) : QSize(360, thickness);
                panel.resize(size);
                item->setSize(size);
                QTest::qWait(80);
                const auto a = expandButton->mapRectToItem(item, expandButton->boundingRect());
                const auto b = controlsButton->mapRectToItem(item, controlsButton->boundingRect());
                const auto c = notificationsButton->mapRectToItem(item, notificationsButton->boundingRect());
                const bool aligned = vertical
                    ? qAbs(a.bottom() - b.top()) < 1 && qAbs(b.bottom() - c.top()) < 1
                        && qAbs(a.height() - b.height()) < 1 && qAbs(b.height() - c.height()) < 1
                        && qAbs(a.center().x() - c.center().x()) < 1
                    : qAbs(a.right() - b.left()) < 1 && qAbs(b.right() - c.left()) < 1
                        && qAbs(a.width() - b.width()) < 1 && qAbs(b.width() - c.width()) < 1
                        && qAbs(a.center().y() - c.center().y()) < 1;
                if (!aligned) {
                    qCritical() << "Unequal panel cells:" << vertical << thickness << a << b << c;
                    app.exit(25); return;
                }
                for (auto *button : {expandButton, controlsButton, notificationsButton}) {
                    auto *glyph = visualChild(button, QStringLiteral("panelGlyph"));
                    if (!glyph || glyph->property("status").toInt() != 1 || !glyph->property("isMask").toBool()) {
                        qCritical("A bundled panel icon is missing or does not follow the palette");
                        app.exit(26); return;
                    }
                }
            }
        }
        parentPanel->setFormFactor(Plasma::Types::Horizontal);
        parentPanel->setLocation(Plasma::Types::BottomEdge);
        panel.resize(360, 40);
        item->setSize(panel.size());
        QTest::qWait(80);
        auto *notificationsApplet = item->property("notificationsApplet").value<QQuickItem *>();
        auto *originalCompact = notificationsApplet ? notificationsApplet->property("compactRepresentationItem").value<QQuickItem *>() : nullptr;
        if (!notificationsApplet || notificationsApplet->opacity() != 0 || (originalCompact && originalCompact->opacity() != 0)) {
            qCritical("The original notification icon is still painting under the new button");
            app.exit(27); return;
        }
        if (qEnvironmentVariableIsSet("CONTROLHUB_DUMP_ICONS")) {
            const auto dump = [](auto &&self, QQuickItem *node, int depth) -> void {
                qInfo() << QString(depth, QLatin1Char(' ')) << node->metaObject()->className() << node->objectName()
                        << node->opacity() << node->isVisible() << node->property("source");
                for (auto *child : node->childItems()) self(self, child, depth + 1);
            };
            dump(dump, notificationsButton, 0);
        }
        QQmlComponent fallbackComponent(qmlEngine(item), QUrl(QStringLiteral("qrc:/qt/qml/plasma/applet/org/eirom/plasma/controlhub/ControlIcon.qml")));
        std::unique_ptr<QObject> fallback(fallbackComponent.createWithInitialProperties({
            {QStringLiteral("source"), QStringLiteral("controlhub-deliberately-missing-icon")},
            {QStringLiteral("controlId"), QStringLiteral("org.kde.plasma.networkmanagement")},
        }));
        auto *fallbackItem = qobject_cast<QQuickItem *>(fallback.get());
        if (fallbackItem) fallbackItem->setParentItem(panel.contentItem());
        QTest::qWait(100);
        auto *fallbackGlyph = fallbackItem ? visualChild(fallbackItem, QStringLiteral("fallbackGlyph")) : nullptr;
        if (!fallbackGlyph || !fallbackGlyph->isVisible() || !fallbackGlyph->property("valid").toBool()) {
            auto *nativeGlyph = fallbackItem ? visualChild(fallbackItem, QStringLiteral("nativeGlyph")) : nullptr;
            qCritical() << "Missing control icons have no valid fallback:" << fallbackComponent.errors()
                        << fallbackItem << (fallbackItem ? fallbackItem->size() : QSizeF())
                        << (fallbackGlyph ? fallbackGlyph->property("valid") : QVariant())
                        << (fallbackGlyph ? fallbackGlyph->property("source") : QVariant())
                        << (nativeGlyph ? nativeGlyph->property("valid") : QVariant());
            app.exit(28); return;
        }
        fallback.reset();
        capture(&panel, QStringLiteral("panel-idle"));
        QMetaObject::invokeMethod(item, "showHome", Q_ARG(QVariant, QVariant(QStringLiteral("controls"))));
        QTest::qWait(350);
        auto *popup = windowNamed(QStringLiteral("controlPopup"));
        if (!popup || !popup->isVisible()) { app.exit(6); return; }
        qInfo() << "Controls geometry:" << popup->geometry();
        capture(popup, QStringLiteral("controls"));
        capture(&panel, QStringLiteral("panel"));
        if (qEnvironmentVariableIsSet("CONTROLHUB_MANUAL")) return;

        // Pin an actual module independently of whether its tile is selected.
        QMetaObject::invokeMethod(item, "setControlVisible", Q_ARG(QVariant, QVariant(QStringLiteral("org.kde.plasma.clipboard"))), Q_ARG(QVariant, QVariant(false)));
        QMetaObject::invokeMethod(item, "setTrayVisibility", Q_ARG(QVariant, QVariant(QStringLiteral("org.kde.plasma.clipboard"))), Q_ARG(QVariant, QVariant(QStringLiteral("shown"))));
        QTest::qWait(100);
        auto *pin = visualChild(item, QStringLiteral("pinnedControl_org.kde.plasma.clipboard"));
        if (!pin || !pin->isVisible() || !containment->configScheme()->property(QStringLiteral("shownItems")).toStringList().contains(QStringLiteral("org.kde.plasma.clipboard"))) {
            qCritical("A selected control could not be pinned to the panel"); app.exit(29); return;
        }
        if (QGuiApplication::platformName() == QStringLiteral("xcb")) {
            QTest::mouseClick(&panel, Qt::LeftButton, Qt::NoModifier, pin->mapToScene(pin->boundingRect().center()).toPoint());
            QTest::qWait(100);
            if (!item->property("systemTrayState").value<QObject *>()->property("activeApplet").value<QObject *>()) {
                qCritical("The pinned module did not open its original KDE view"); app.exit(30); return;
            }
        }
        capture(&panel, QStringLiteral("panel-pinned"));
        QMetaObject::invokeMethod(item, "showHome", Q_ARG(QVariant, QVariant(QStringLiteral("controls"))));
        QMetaObject::invokeMethod(item, "setTrayVisibility", Q_ARG(QVariant, QVariant(QStringLiteral("org.kde.plasma.clipboard"))), Q_ARG(QVariant, QVariant(QStringLiteral("auto"))));
        QMetaObject::invokeMethod(item, "setControlVisible", Q_ARG(QVariant, QVariant(QStringLiteral("org.kde.plasma.clipboard"))), Q_ARG(QVariant, QVariant(true)));
        QTest::qWait(100);
        if (visualChild(item, QStringLiteral("pinnedControl_org.kde.plasma.clipboard"))) {
            qCritical("An unpinned control remained in the panel"); app.exit(31); return;
        }

        auto *volume = visualChild(popup->contentItem(), QStringLiteral("volumeControl"));
        auto *brightness = visualChild(popup->contentItem(), QStringLiteral("brightnessControl"));
        if (!volume || !brightness || brightness->mapToScene(QPointF()).y() >= volume->mapToScene(QPointF()).y()) {
            qCritical("The fixed brightness/volume footer is missing or incorrectly ordered");
            app.exit(8); return;
        }
        qInfo() << "Footer positions:" << brightness->mapRectToScene(brightness->boundingRect()) << volume->mapRectToScene(volume->boundingRect());
        item->setProperty("editing", true);
        QTest::qWait(120);
        capture(popup, QStringLiteral("editor"));
        if (QGuiApplication::platformName() == QStringLiteral("xcb")) {
            auto *from = visualChild(popup->contentItem(), QStringLiteral("controlRow_org.kde.plasma.bluetooth"));
            auto *to = visualChild(popup->contentItem(), QStringLiteral("controlRow_org.kde.plasma.networkmanagement"));
            if (!from || !to) { app.exit(20); return; }
            const auto source = popup->mapToGlobal(from->mapToScene(QPointF(100, from->height()/2)).toPoint());
            const auto target = popup->mapToGlobal(to->mapToScene(QPointF(100, to->height()/2)).toPoint());
            if (!drivePointer(source, target, popup->devicePixelRatio()) || containment->configScheme()->property(QStringLiteral("controlOrder")).toStringList().first() != QStringLiteral("org.kde.plasma.bluetooth")) {
                qCritical("Control reordering by drag failed"); app.exit(21); return;
            }
        }
        QMetaObject::invokeMethod(item, "setControlVisible", Q_ARG(QVariant, QVariant(QStringLiteral("org.kde.plasma.clipboard"))), Q_ARG(QVariant, QVariant(false)));
        QTest::qWait(50);
        if (containment->configScheme()->property(QStringLiteral("selectedControls")).toStringList().contains(QStringLiteral("org.kde.plasma.clipboard"))) {
            app.exit(9); return;
        }
        QMetaObject::invokeMethod(item, "setControlVisible", Q_ARG(QVariant, QVariant(QStringLiteral("org.kde.plasma.clipboard"))), Q_ARG(QVariant, QVariant(true)));
        QMetaObject::invokeMethod(item, "moveControl", Q_ARG(QVariant, QVariant(QStringLiteral("org.kde.plasma.bluetooth"))), Q_ARG(QVariant, QVariant(QStringLiteral("org.kde.plasma.networkmanagement"))));
        QTest::qWait(50);
        if (containment->configScheme()->property(QStringLiteral("controlOrder")).toStringList().first() != QStringLiteral("org.kde.plasma.bluetooth")) {
            app.exit(10); return;
        }
        containment->configScheme()->save();
        corona.requireConfigSync();
        const auto hosts = item->property("hosts").value<QJSValue>();
        auto *audioApplet = hosts.property(QStringLiteral("org.kde.plasma.volume")).property(QStringLiteral("applet")).toQObject();
        if (!audioApplet) { app.exit(11); return; }
        QMetaObject::invokeMethod(item, "openControl", Q_ARG(QVariant, QVariant::fromValue(audioApplet)));
        QTest::qWait(250);
        capture(popup, QStringLiteral("audio-options"));

        // Exercise both the original SNI model and native cross-window dragging.
        QMetaObject::invokeMethod(item, "setTrayVisibility", Q_ARG(QVariant, QVariant(QStringLiteral("controlhub-smoke_controlhub-fixture"))), Q_ARG(QVariant, QVariant(QStringLiteral("hidden"))));
        QMetaObject::invokeMethod(item, "showHome", Q_ARG(QVariant, QVariant(QStringLiteral("applications"))));
        QTest::qWait(200);
        auto *trayIcon = visualChild(popup->contentItem(), QStringLiteral("trayItem_controlhub-smoke_controlhub-fixture"));
        if (!trayIcon) {
            qCritical() << "SNI fixture missing; watcher items:" << watcher.items();
            auto *model = containment->property("systemTrayModel").value<QAbstractItemModel *>();
            if (model) for (int i = 0; i < model->rowCount(); ++i) {
                const auto index = model->index(i, 0);
                qInfo() << "ROW" << model->data(index, Qt::UserRole + 1) << model->data(index, Qt::UserRole + 2) << model->data(index, Qt::UserRole + 6);
            }
            capture(popup, QStringLiteral("hidden-applications"));
            app.exit(16); return;
        }
        capture(popup, QStringLiteral("hidden-applications"));
        if (QGuiApplication::platformName() == QStringLiteral("xcb")) {
            const auto source = popup->mapToGlobal(trayIcon->mapToScene(trayIcon->boundingRect().center()).toPoint());
            const auto target = panel.mapToGlobal(QPoint(panel.width() - 3, panel.height() / 2));
            if (!drivePointer(source, target, panel.devicePixelRatio())) { app.exit(17); return; }
            if (!containment->configScheme()->property(QStringLiteral("shownItems")).toStringList().contains(QStringLiteral("controlhub-smoke_controlhub-fixture"))) {
                qCritical("Cross-window drag did not pin the application"); app.exit(18); return;
            }
        }
        auto notification = QDBusMessage::createMethodCall(QStringLiteral("org.freedesktop.Notifications"), QStringLiteral("/org/freedesktop/Notifications"), QStringLiteral("org.freedesktop.Notifications"), QStringLiteral("Notify"));
        notification.setArguments({QStringLiteral("Control Hub"), uint(0), QStringLiteral("dialog-information"), QStringLiteral("Notificaciones de KDE"), QStringLiteral("El historial original se muestra desde el borde derecho."), QStringList(), QVariantMap{{QStringLiteral("urgency"), QVariant::fromValue(static_cast<uchar>(1))}, {QStringLiteral("desktop-entry"), QStringLiteral("org.eirom.ControlHubSmoke")}}, 1000});
        auto pendingNotification = QDBusConnection::sessionBus().asyncCall(notification);
        QTest::qWait(300);
        QDBusPendingReply<uint> notificationReply(pendingNotification);
        qInfo() << "Notify reply:" << notificationReply.isFinished() << notificationReply.error();
        QTest::qWait(1600); // Let the native toast expire into unread history.
        capture(&panel, QStringLiteral("panel-unread"));
        QMetaObject::invokeMethod(item, "openNotifications");
        QTest::qWait(250);
        auto *drawer = windowNamed(QStringLiteral("notificationDrawer"));
        if (!drawer || !drawer->isVisible()) { app.exit(12); return; }
        const auto area = drawer->property("availableGeometry").toRect();
        QRect actualGeometry = drawer->geometry();
        if (QGuiApplication::platformName().startsWith(QStringLiteral("wayland"))) {
            QTemporaryFile probeScript;
            if (!probeScript.open()) { app.exit(22); return; }
            const QString script = QStringLiteral("for (const w of workspace.windowList()) { const g = w.frameGeometry; { callDBus('org.eirom.ControlHubSmoke', '/GeometryProbe', 'org.eirom.ControlHubSmoke.Geometry', 'report', Math.round(g.x), Math.round(g.y), Math.round(g.width), Math.round(g.height)); } }");
            probeScript.write(script.toUtf8());
            probeScript.flush();
            QDBusInterface scripting(QStringLiteral("org.kde.KWin"), QStringLiteral("/Scripting"), QStringLiteral("org.kde.kwin.Scripting"));
            QDBusReply<int> scriptId = scripting.call(QStringLiteral("loadScript"), probeScript.fileName(), QStringLiteral("controlhub-geometry"));
            if (!scriptId.isValid()) { qCritical() << scriptId.error(); app.exit(23); return; }
            QDBusInterface loaded(QStringLiteral("org.kde.KWin"), QStringLiteral("/Scripting/Script%1").arg(scriptId.value()), QStringLiteral("org.kde.kwin.Script"));
            loaded.call(QStringLiteral("run"));
            QTest::qWait(300);
            if (!geometryProbe.ready) { qCritical("KWin did not return the actual drawer geometry"); app.exit(24); return; }
            actualGeometry = geometryProbe.geometry;
        }
        qInfo() << "Notification geometry:" << actualGeometry << "available:" << area;
        if (actualGeometry.x() + actualGeometry.width() != area.x() + area.width() || actualGeometry.y() != area.y() || actualGeometry.height() > area.height()) {
            app.exit(13); return;
        }
        auto *notificationApplet = hosts.property(QStringLiteral("org.kde.plasma.notifications")).property(QStringLiteral("applet")).toQObject();
        auto *fullHistory = notificationApplet ? notificationApplet->property("fullRepresentationItem").value<QObject *>() : nullptr;
        auto *history = fullHistory ? qobject_cast<QAbstractItemModel *>(fullHistory->property("historyModel").value<QObject *>()) : nullptr;
        if (!history || history->rowCount() < 1) {
            qCritical() << "Native history missing:" << notificationApplet << fullHistory << history << "server valid:" << NotificationManager::Server::self().isValid();
            if (fullHistory) qInfo() << "History property:" << fullHistory->property("historyModel");
            for (auto *model = history; model; ) {
                qInfo() << "Notification model:" << model->metaObject()->className() << model->rowCount();
                const auto *proxy = qobject_cast<QSortFilterProxyModel *>(model);
                model = proxy ? proxy->sourceModel() : nullptr;
            }
            if (history) qInfo() << history->property("blacklistedDesktopEntries") << history->property("blacklistedNotifyRcNames") << history->property("urgencies");
            capture(drawer, QStringLiteral("notifications"));
            app.exit(19); return;
        }
        capture(drawer, QStringLiteral("notifications"));
        item->setProperty("notificationsOpen", false);
        QTest::qWait(100);
        if (drawer->isVisible()) { app.exit(14); return; }
        qInfo() << "Integration completed; QML errors:" << invalidQml;
        app.exit(invalidQml ? 15 : 0);
    });
    QTimer::singleShot(15000, &app, [&]() { if (!qEnvironmentVariableIsSet("CONTROLHUB_MANUAL")) app.exit(7); });
    return app.exec();
}
