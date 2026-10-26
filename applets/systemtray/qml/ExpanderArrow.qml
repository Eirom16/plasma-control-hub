/*
    SPDX-FileCopyrightText: 2013 Sebastian Kügler <sebas@kde.org>
    SPDX-FileCopyrightText: 2015 Marco Martin <mart@kde.org>
    SPDX-FileCopyrightText: 2026 Eirom16
    SPDX-License-Identifier: LGPL-2.0-or-later
*/
import QtQuick
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

PanelButton {
    id: button
    readonly property bool drawerOpen: systemTrayState.expanded && root.popupMode === "applications"
    glyphSource: Qt.resolvedUrl("icons/hub-chevron-up.svg")
    glyphRotation: {
        const direction = Plasmoid.location === PlasmaCore.Types.TopEdge ? 180
            : Plasmoid.location === PlasmaCore.Types.LeftEdge ? 90
            : Plasmoid.location === PlasmaCore.Types.RightEdge ? -90 : 0;
        return direction + (drawerOpen ? 180 : 0);
    }
    text: drawerOpen ? i18n("Close popup") : i18n("Show hidden icons")
    Accessible.description: i18n("Show all the items in the system tray in a popup")
    checked: drawerOpen
    onClicked: {
        root.toggleHome("applications");
        expandedRepresentation.hiddenLayout.currentIndex = -1;
    }
}
