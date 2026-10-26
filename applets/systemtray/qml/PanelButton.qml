// SPDX-FileCopyrightText: 2026 Eirom16
// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

PlasmaComponents.ToolButton {
    id: button
    property int iconSize: Kirigami.Units.iconSizes.smallMedium
    property url glyphSource
    property real glyphRotation: 0
    // The parent owns cell dimensions; the theme owns hover, focus and colors.
    implicitWidth: iconSize
    implicitHeight: iconSize
    padding: 0
    display: PlasmaComponents.AbstractButton.IconOnly
    contentItem: Item {
        Kirigami.Icon {
            objectName: "panelGlyph"
            anchors.centerIn: parent
            width: button.iconSize
            height: button.iconSize
            source: button.glyphSource
            isMask: true
            rotation: button.glyphRotation
            Behavior on rotation {
                RotationAnimation { duration: Kirigami.Units.shortDuration }
            }
        }
    }
    PlasmaComponents.ToolTip { text: button.text }
}
