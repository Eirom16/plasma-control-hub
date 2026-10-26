// SPDX-FileCopyrightText: 2026 Eirom16
// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import org.kde.kirigami as Kirigami
import "ControlIcons.js" as ControlIcons

Item {
    id: controlIcon
    property var source
    property string controlId
    implicitWidth: Kirigami.Units.iconSizes.smallMedium
    implicitHeight: implicitWidth
    Kirigami.Icon {
        id: nativeIcon
        objectName: "nativeGlyph"
        anchors.fill: parent
        source: controlIcon.source
        visible: valid && status !== Kirigami.Icon.Error
    }
    Kirigami.Icon {
        objectName: "fallbackGlyph"
        anchors.fill: parent
        source: Qt.resolvedUrl("icons/hub-" + ControlIcons.fallback(controlIcon.controlId) + ".svg")
        isMask: true
        visible: !nativeIcon.valid || nativeIcon.status === Kirigami.Icon.Error
    }
}
