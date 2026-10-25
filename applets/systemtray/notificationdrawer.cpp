// SPDX-FileCopyrightText: 2026 Eirom16
// SPDX-License-Identifier: GPL-2.0-or-later
#include "notificationdrawer.h"
#include <Plasma/Applet>
#include <Plasma/Containment>
#include <Plasma/Corona>
#include <PlasmaQuick/PlasmaShellWaylandIntegration>
#include <KWindowEffects>
#include <KWindowSystem>
#include <QEvent>
#include <QGuiApplication>
#include <QScreen>

NotificationDrawer::NotificationDrawer(QQuickItem *parent)
    : PlasmaQuick::Dialog(parent)
{
    setLocation(Plasma::Types::RightEdge);
    setType(PlasmaQuick::Dialog::AppletPopup);
    setHideOnWindowDeactivate(true);
    connect(this, &PlasmaQuick::Dialog::visualParentChanged, this, &NotificationDrawer::availableGeometryChanged);
    connect(this, &QWindow::screenChanged, this, &NotificationDrawer::availableGeometryChanged);
    connect(this, &NotificationDrawer::availableGeometryChanged, this, [this]() {
        if (isVisible()) applyPosition();
    });
    for (auto *output : QGuiApplication::screens()) {
        connect(output, &QScreen::availableGeometryChanged, this, &NotificationDrawer::availableGeometryChanged);
        connect(output, &QScreen::geometryChanged, this, &NotificationDrawer::availableGeometryChanged);
    }
    connect(qGuiApp, &QGuiApplication::screenAdded, this, [this](QScreen *output) {
        connect(output, &QScreen::availableGeometryChanged, this, &NotificationDrawer::availableGeometryChanged);
        connect(output, &QScreen::geometryChanged, this, &NotificationDrawer::availableGeometryChanged);
        Q_EMIT availableGeometryChanged();
    });
}

QRect NotificationDrawer::availableGeometry() const
{
    if (const auto *anchor = visualParent()) {
        auto *applet = anchor->property("_plasma_applet").value<Plasma::Applet *>();
        auto *containment = qobject_cast<Plasma::Containment *>(applet);
        if (!containment && applet) containment = applet->containment();
        if (containment && containment->corona()) {
            const int output = containment->screen();
            if (output >= 0) {
                const QRect area = containment->corona()->availableScreenRect(output);
                if (area.isValid()) {
                    return area;
                }
            }
        }
        if (anchor->window() && anchor->window()->screen()) {
            return anchor->window()->screen()->availableGeometry();
        }
    }
    return screen() ? screen()->availableGeometry() : QRect(0, 0, 1024, 768);
}

QPoint NotificationDrawer::popupPosition(QQuickItem *, const QSize &size)
{
    const QRect area = availableGeometry();
    return QPoint(area.x() + area.width() - size.width(), area.y());
}

void NotificationDrawer::applyPosition()
{
    const QPoint wanted = popupPosition(visualParent(), size());
    if (!KWindowSystem::isPlatformWayland() && position() != wanted) setPosition(wanted);
    // A Wayland configure may report (0,0) for this top-level and the base dialog
    // then copies that into the shell surface. Reapply the absolute edge anchor
    // through the same native integration used by Plasma's own windows.
    PlasmaShellWaylandIntegration::get(this)->setPosition(wanted);
}

bool NotificationDrawer::event(QEvent *event)
{
    const auto type = event->type();
    const bool handled = PlasmaQuick::Dialog::event(event);
    if (isVisible() && (type == QEvent::Show || type == QEvent::Move || type == QEvent::Resize || type == QEvent::Expose)) {
        applyPosition();
    }
    return handled;
}

void NotificationDrawer::showEvent(QShowEvent *event)
{
    if (visualParent() && visualParent()->window()) {
        setScreen(visualParent()->window()->screen());
    }
    if (visualParent()) {
        auto *containment = visualParent()->property("_plasma_applet").value<Plasma::Containment *>();
        if (containment && containment->corona()) {
            connect(containment->corona(), &Plasma::Corona::availableScreenRectChanged,
                    this, &NotificationDrawer::availableGeometryChanged, Qt::UniqueConnection);
        }
    }
    Q_EMIT availableGeometryChanged();
    PlasmaQuick::Dialog::showEvent(event);
    applyPosition();
    KWindowEffects::slideWindow(this, m_animationEnabled ? KWindowEffects::RightEdge : KWindowEffects::NoEdge);
}
