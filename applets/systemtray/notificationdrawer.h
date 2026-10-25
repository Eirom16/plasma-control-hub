// SPDX-FileCopyrightText: 2026 Eirom16
// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <PlasmaQuick/Dialog>

// The native Plasma dialog supplies theme, blur, focus and Wayland integration.
// Only its placement is changed: it belongs to the screen edge, not the icon.
class NotificationDrawer : public PlasmaQuick::Dialog
{
    Q_OBJECT
    Q_PROPERTY(QRect availableGeometry READ availableGeometry NOTIFY availableGeometryChanged)
    Q_PROPERTY(bool animationEnabled MEMBER m_animationEnabled)
public:
    explicit NotificationDrawer(QQuickItem *parent = nullptr);
    QRect availableGeometry() const;
    Q_INVOKABLE void activateDrawer() { requestActivate(); }
    QPoint popupPosition(QQuickItem *item, const QSize &size) override;
Q_SIGNALS:
    void availableGeometryChanged();
protected:
    void showEvent(QShowEvent *event) override;
    bool event(QEvent *event) override;
private:
    void applyPosition();
    bool m_animationEnabled = true;
};
