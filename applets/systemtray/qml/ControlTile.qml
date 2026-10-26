// SPDX-FileCopyrightText: 2026 Eirom16
// SPDX-License-Identifier: GPL-2.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras

PlasmaComponents.Frame {
    id: tile
    required property var entry
    required property var hub
    readonly property var toggleAction: {
        if (!entry.applet) return null;
        if (entry.id === "org.kde.plasma.bluetooth") return entry.applet.toggleBluetoothAction ?? null;
        if (entry.id === "org.kde.plasma.networkmanagement") {
            return entry.applet.plasmoid.contextualActions.find(action => action.icon.name === "network-wireless-on") ?? null;
        }
        return null;
    }
    readonly property bool canToggle: toggleAction !== null && toggleAction.visible
    readonly property var allActions: {
        if (!entry.applet) return [];
        const actions = entry.applet.plasmoid.contextualActions.slice();
        const configure = entry.applet.plasmoid.internalAction("configure");
        if (configure && !actions.includes(configure)) actions.push(configure);
        return actions.filter(action => action && action.visible);
    }
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: contextMenu.openRelative()
    }
    Keys.onMenuPressed: contextMenu.openRelative()
    PlasmaExtras.Menu {
        id: contextMenu
        visualParent: tile
        placement: PlasmaExtras.Menu.BottomPosedLeftAlignedPopup
    }
    Instantiator {
        model: tile.allActions
        delegate: PlasmaExtras.MenuItem {
            required property var modelData
            action: modelData
        }
        onObjectAdded: (index, object) => contextMenu.addMenuItem(object)
        onObjectRemoved: (index, object) => contextMenu.removeMenuItem(object)
    }
    padding: Kirigami.Units.smallSpacing
    implicitHeight: content.implicitHeight + topPadding + bottomPadding
    contentItem: ColumnLayout {
        id: content
        spacing: Kirigami.Units.smallSpacing
        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents.ToolButton {
                id: primary
                Layout.fillWidth: true
                text: tile.entry.title
                enabled: tile.entry.applet !== null && (!tile.canToggle || tile.toggleAction.enabled)
                checkable: tile.canToggle
                checked: tile.canToggle && tile.toggleAction.checked
                onClicked: {
                    if (tile.canToggle) tile.toggleAction.trigger();
                    else tile.hub.openControl(tile.entry.applet);
                }
                contentItem: RowLayout {
                    spacing: Kirigami.Units.smallSpacing
                    ControlIcon {
                        Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                        Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                        source: tile.entry.icon
                        controlId: tile.entry.id
                    }
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: primary.text
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                    }
                }
                PlasmaComponents.ToolTip {
                    text: tile.canToggle ? tile.toggleAction.text : tile.entry.title
                }
            }
            PlasmaComponents.ToolButton {
                id: details
                icon.name: "go-next-symbolic"
                text: i18n("Show %1 options", tile.entry.title)
                display: PlasmaComponents.AbstractButton.IconOnly
                enabled: tile.entry.applet !== null
                onClicked: tile.hub.openControl(tile.entry.applet)
                PlasmaComponents.ToolTip { text: details.text }
            }
        }
        PlasmaComponents.Label {
            Layout.fillWidth: true
            leftPadding: Kirigami.Units.smallSpacing
            text: !tile.entry.applet ? i18n("Service unavailable") : tile.canToggle ? (tile.toggleAction.checked ? i18n("On") : i18n("Off")) : tile.entry.applet.toolTipSubText || i18n("Show options")
            textFormat: Text.PlainText
            elide: Text.ElideRight
            maximumLineCount: 1
            opacity: 0.7
        }
    }
}
