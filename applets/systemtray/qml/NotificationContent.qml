// SPDX-FileCopyrightText: 2026 Eirom16
// SPDX-License-Identifier: GPL-2.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras

ColumnLayout {
    id: content
    required property var applet
    signal closeRequested()
    spacing: 0
    function adopt() {
        const item = applet?.fullRepresentationItem;
        if (!item) return;
        item.anchors.left = undefined;
        item.anchors.right = undefined;
        item.anchors.top = undefined;
        item.anchors.bottom = undefined;
        item.anchors.centerIn = undefined;
        item.parent = representation;
        item.anchors.fill = representation;
        item.visible = true;
    }
    onAppletChanged: adopt()
    Keys.onEscapePressed: closeRequested()
    PlasmaExtras.PlasmoidHeading {
        Layout.fillWidth: true
        RowLayout {
            anchors.fill: parent
            Kirigami.Heading {
                Layout.fillWidth: true
                level: 1
                text: i18n("Notifications")
                elide: Text.ElideRight
            }
            PlasmaComponents.ToolButton {
                id: configure
                text: i18n("Configure notifications")
                icon.name: "configure"
                display: PlasmaComponents.AbstractButton.IconOnly
                enabled: content.applet?.plasmoid.internalAction("configure")?.enabled ?? false
                onClicked: content.applet.plasmoid.internalAction("configure").trigger()
                PlasmaComponents.ToolTip { text: configure.text }
            }
            PlasmaComponents.ToolButton {
                id: close
                text: i18n("Close")
                icon.name: "window-close"
                display: PlasmaComponents.AbstractButton.IconOnly
                onClicked: content.closeRequested()
                PlasmaComponents.ToolTip { text: close.text }
            }
        }
    }
    Item {
        id: representation
        Layout.fillWidth: true
        Layout.fillHeight: true
    }
    Connections {
        target: content.applet
        function onFullRepresentationItemChanged() { content.adopt(); }
    }
}
