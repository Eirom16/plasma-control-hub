/*
    SPDX-FileCopyrightText: 2011 Marco Martin <mart@kde.org>
    SPDX-FileCopyrightText: 2020 Konrad Materka <materka@gmail.com>
    SPDX-FileCopyrightText: 2026 Nathaniel Krebs <areyoufeelingitnowmrkrebs@gmail.com>
    SPDX-FileCopyrightText: 2026 Eirom16
    SPDX-License-Identifier: LGPL-2.0-or-later
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kitemmodels as KItemModels
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid
import org.eirom.plasma.controlhub 1.0
import "ControlLayout.js" as ControlLayout

ContainmentItem {
    id: root
    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool reverseLayout: Plasmoid.configuration.reverseIconOrder
    readonly property alias systemTrayState: systemTrayState
    readonly property alias itemSize: tasksGrid.itemSize
    readonly property alias visibleLayout: tasksGrid
    readonly property alias hiddenLayout: expandedRepresentation.hiddenLayout
    readonly property alias hiddenModel: hiddenModel
    readonly property bool oneRowOrColumn: tasksGrid.rowsOrColumns === 1
    readonly property int panelCellLength: root.vertical ? tasksGrid.cellHeight : tasksGrid.cellWidth
    property string popupMode: "controls"
    property bool editing: false
    property bool notificationsOpen: false
    property var hosts: ({})
    property var controlEntries: []
    readonly property var notificationsApplet: hosts["org.kde.plasma.notifications"]?.applet ?? null
    readonly property int unreadCount: notificationsApplet?.unreadCount ?? 0

    Layout.minimumWidth: mainLayout.implicitWidth
    Layout.minimumHeight: mainLayout.implicitHeight
    Layout.preferredWidth: mainLayout.implicitWidth
    Layout.preferredHeight: mainLayout.implicitHeight
    LayoutMirroring.enabled: !vertical && ((Application.layoutDirection === Qt.RightToLeft) !== reverseLayout)
    LayoutMirroring.childrenInherit: true

    Timer { id: controlsRefresh; interval: 0; onTriggered: root.rebuildControls() }
    function refreshControls() { controlsRefresh.restart(); }
    function rebuildControls() {
        const entries = Object.keys(hosts).filter(id => id !== "org.kde.plasma.notifications").map(id => ({
            id: id, title: hosts[id].displayText, icon: hosts[id].decoration, applet: hosts[id].applet ?? null
        }));
        controlEntries = ControlLayout.sorted(entries, Plasmoid.configuration.controlOrder);
    }
    function registerHost(id, host) {
        if (!id || !host) return;
        const next = Object.assign({}, hosts);
        next[id] = host;
        hosts = next;
        refreshControls();
    }
    function unregisterHost(id, host) {
        if (hosts[id] !== host) return;
        const next = Object.assign({}, hosts);
        delete next[id];
        hosts = next;
        refreshControls();
    }
    function setControlVisible(id, visible) {
        const selected = Plasmoid.configuration.selectedControls.filter(value => value !== id);
        if (visible) selected.push(id);
        Plasmoid.configuration.selectedControls = selected;
        // Enabling a tile must not change the service's actual on/off state.
        if (visible && !Plasmoid.configuration.extraItems.includes(id)) {
            Plasmoid.configuration.extraItems = Plasmoid.configuration.extraItems.concat([id]);
        }
    }
    function isControlPinned(id) {
        return Plasmoid.configuration.showAllItems || Plasmoid.configuration.shownItems.includes(id);
    }
    function moveControl(id, before) {
        const order = controlEntries.map(entry => entry.id);
        Plasmoid.configuration.controlOrder = ControlLayout.move(order, id, before);
        refreshControls();
    }
    function setTrayVisibility(id, mode) {
        Plasmoid.setItemVisibility(id, mode);
    }
    function showHome(mode) {
        notificationsOpen = false;
        if (notificationsApplet) notificationsApplet.expanded = false;
        systemTrayState.setActiveApplet(null);
        popupMode = mode;
        editing = false;
        systemTrayState.expanded = true;
    }
    function toggleHome(mode) {
        if (systemTrayState.expanded && popupMode === mode && !systemTrayState.activeApplet) {
            systemTrayState.expanded = false;
        } else {
            showHome(mode);
        }
    }
    function openControl(applet) {
        if (!applet) return;
        // Some tray applets are direct actions rather than expandable panels.
        if (!applet.fullRepresentation || applet.preferredRepresentation === applet.fullRepresentation) {
            const configure = applet.plasmoid.internalAction("configure");
            if (configure?.enabled) configure.trigger();
            else applet.plasmoid.activated();
            return;
        }
        notificationsOpen = false;
        if (notificationsApplet) notificationsApplet.expanded = false;
        popupMode = "controls";
        editing = false;
        systemTrayState.setActiveApplet(applet);
    }
    function openNotifications() {
        if (!notificationsApplet) return;
        systemTrayState.expanded = false;
        notificationsOpen = true;
        notificationsApplet.expanded = true;
        notificationContent.adopt();
    }

    Connections {
        target: Plasmoid.configuration
        function onControlOrderChanged() { root.refreshControls(); }
    }
    Connections {
        target: Plasmoid
        function onActivated() { root.toggleHome("controls"); }
    }

    KItemModels.KSortFilterProxyModel {
        id: activeModel
        filterRowCallback: (row, parent) => {
            const index = sourceModel.index(row, 0, parent);
            return sourceModel.data(index, Qt.UserRole + 1) !== "Plasmoid"
                && sourceModel.data(index, Qt.UserRole + 6) === PlasmaCore.Types.ActiveStatus;
        }
        Component.onCompleted: sourceModel = Plasmoid.systemTrayModel
    }
    KItemModels.KSortFilterProxyModel {
        id: hiddenModel
        filterRowCallback: (row, parent) => {
            const index = sourceModel.index(row, 0, parent);
            return sourceModel.data(index, Qt.UserRole + 1) !== "Plasmoid"
                && sourceModel.data(index, Qt.UserRole + 6) === PlasmaCore.Types.PassiveStatus;
        }
        Component.onCompleted: sourceModel = Plasmoid.systemTrayModel
    }
    KItemModels.KSortFilterProxyModel {
        id: appletsModel
        filterRoleName: "itemType"
        filterString: "Plasmoid"
        Component.onCompleted: sourceModel = Plasmoid.systemTrayModel
    }

    // One owner per upstream applet. Its original full representation is moved
    // into the details view only while needed, retaining actions and shortcuts.
    Instantiator {
        id: appletHosts
        active: false
        model: appletsModel
        delegate: Item {
            id: host
            required property string itemId
            required property string displayText
            required property var decoration
            required property var applet
            parent: appletStorage
            visible: false
            function hideOriginalNotificationIcon() {
                if (itemId !== "org.kde.plasma.notifications" || !applet) return;
                applet.opacity = 0;
                if (applet.compactRepresentationItem) {
                    // AppletQuickItem may reparent this outside its own root.
                    applet.compactRepresentationItem.opacity = 0;
                    applet.compactRepresentationItem.enabled = false;
                }
            }
            function adopt() {
                if (itemId === "org.kde.plasma.notifications") {
                    // Keep the original compact item's screen geometry at the
                    // visible button, so KDE's "close to widget" toasts anchor
                    // correctly even though we draw our own compact button.
                    host.parent = notificationsButton;
                    host.anchors.fill = notificationsButton;
                }
                if (applet) {
                    applet.parent = host;
                    applet.anchors.fill = host;
                    applet.visible = true;
                    // AppletQuickItem can restore compact visibility itself.
                    // Keep notification geometry for toast placement without
                    // painting its original bell over our own button.
                    hideOriginalNotificationIcon();
                }
                root.registerHost(itemId, host);
            }
            onAppletChanged: adopt()
            onDisplayTextChanged: root.refreshControls()
            onDecorationChanged: root.refreshControls()
            Component.onCompleted: adopt()
            Component.onDestruction: root.unregisterHost(itemId, host)
            Connections {
                target: host.applet ?? null
                function onExpandedChanged() {
                    if (host.itemId === "org.kde.plasma.notifications") {
                        if (host.applet.expanded && !root.notificationsOpen) root.openNotifications();
                        else if (!host.applet.expanded) root.notificationsOpen = false;
                    } else if (host.applet.expanded && systemTrayState.activeApplet !== host.applet) {
                        root.openControl(host.applet);
                    }
                }
                function onFullRepresentationItemChanged() {
                    if (host.itemId === "org.kde.plasma.notifications") notificationContent.adopt();
                }
                function onCompactRepresentationItemChanged() { host.hideOriginalNotificationIcon(); }
            }
        }
    }
    Item { id: appletStorage; visible: false }
    Component.onCompleted: appletHosts.active = true

    SystemTrayState { id: systemTrayState }
    DropArea {
        anchors.fill: parent
        keys: ["application/x-controlhub-tray-id"]
        onDropped: drop => {
            const id = drop.getDataAsString("application/x-controlhub-tray-id") || drop.source?.itemId;
            if (id) {
                root.setTrayVisibility(id, "shown");
                drop.acceptProposedAction();
            }
        }
    }
    GridLayout {
        id: mainLayout
        // Use the same cells as the SNI grid. Extra host space stays outside
        // the row instead of being distributed between unlike implicit sizes.
        anchors.centerIn: parent
        width: root.vertical ? root.width : implicitWidth
        height: root.vertical ? implicitHeight : root.height
        rowSpacing: 0
        columnSpacing: 0
        flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rows: root.vertical ? -1 : 1
        columns: root.vertical ? 1 : -1

        GridView {
            id: tasksGrid
            readonly property int smallIconSize: Kirigami.Units.iconSizes.smallMedium
            readonly property bool autoSize: Plasmoid.configuration.scaleIconsToFit
            readonly property int gridThickness: root.vertical ? root.width : root.height
            readonly property int rowsOrColumns: autoSize ? 1 : Math.max(1, Math.min(count, Math.floor(gridThickness / (smallIconSize + Kirigami.Units.smallSpacing))))
            readonly property int cellSpacing: Kirigami.Units.smallSpacing * Plasmoid.configuration.iconSpacing
            readonly property int smallSizeCellLength: gridThickness < smallIconSize ? smallIconSize : smallIconSize + cellSpacing
            readonly property int itemSize: autoSize ? Kirigami.Units.iconSizes.roundedIconSize(Math.min(Math.min(root.width, root.height) / rowsOrColumns, Kirigami.Units.iconSizes.enormous)) : smallIconSize
            cellWidth: root.vertical ? (autoSize ? root.width : Math.floor(root.width / rowsOrColumns)) : (autoSize ? itemSize + (gridThickness < itemSize ? 0 : cellSpacing) : smallSizeCellLength)
            cellHeight: root.vertical ? (autoSize ? itemSize + (gridThickness < itemSize ? 0 : cellSpacing) : smallSizeCellLength) : (autoSize ? root.height : Math.floor(root.height / rowsOrColumns))
            implicitWidth: root.vertical ? smallIconSize : cellWidth * Math.ceil(count / rowsOrColumns)
            implicitHeight: root.vertical ? cellHeight * Math.ceil(count / rowsOrColumns) : smallIconSize
            verticalLayoutDirection: root.vertical && root.reverseLayout ? GridView.BottomToTop : GridView.TopToBottom
            Layout.fillWidth: root.vertical
            Layout.fillHeight: !root.vertical
            flow: root.vertical ? GridView.LeftToRight : GridView.TopToBottom
            interactive: false
            model: activeModel
            delegate: ItemLoader {
                width: tasksGrid.cellWidth
                height: tasksGrid.cellHeight
            }
            DropArea {
                anchors.fill: parent
                keys: ["application/x-controlhub-tray-id"]
                onDropped: drop => {
                    const id = drop.getDataAsString("application/x-controlhub-tray-id") || drop.source?.itemId;
                    if (id) {
                        root.setTrayVisibility(id, "shown");
                        drop.acceptProposedAction();
                    }
                }
            }
        }
        Repeater {
            model: root.controlEntries.filter(entry => root.isControlPinned(entry.id))
            delegate: PanelButton {
                id: pinnedButton
                required property var modelData
                objectName: "pinnedControl_" + modelData.id
                Layout.fillWidth: root.vertical
                Layout.fillHeight: !root.vertical
                Layout.preferredWidth: root.vertical ? -1 : root.panelCellLength
                Layout.preferredHeight: root.vertical ? root.panelCellLength : -1
                iconSize: tasksGrid.itemSize
                text: modelData.title
                checked: systemTrayState.expanded && modelData.applet !== null && systemTrayState.activeApplet === modelData.applet
                enabled: modelData.applet !== null
                onClicked: {
                    if (checked) systemTrayState.expanded = false;
                    else root.openControl(modelData.applet);
                }
                contentItem: Item {
                    Item {
                        id: nativeSlot
                        anchors.centerIn: parent
                        width: pinnedButton.iconSize
                        height: pinnedButton.iconSize
                        ControlIcon {
                            anchors.fill: parent
                            source: pinnedButton.modelData.icon
                            controlId: pinnedButton.modelData.id
                            visible: !pinnedButton.modelData.applet?.compactRepresentationItem
                                && !pinnedButton.modelData.applet?.fullRepresentationItem
                        }
                    }
                }
                // Keep the original compact view and its interactions, including
                // text input-method indicators and module-specific wheel actions.
                function adopt() {
                    const host = root.hosts[modelData.id];
                    if (!host) return;
                    host.parent = nativeSlot;
                    host.anchors.fill = nativeSlot;
                    host.visible = true;
                }
                onModelDataChanged: adopt()
                Component.onCompleted: adopt()
                Component.onDestruction: {
                    const host = root.hosts[modelData.id];
                    if (host && host.parent === nativeSlot) {
                        host.visible = false;
                        host.parent = appletStorage;
                    }
                }
            }
        }
        ExpanderArrow {
            id: expander
            objectName: "expanderButton"
            Layout.fillWidth: root.vertical
            Layout.fillHeight: !root.vertical
            Layout.preferredWidth: root.vertical ? -1 : root.panelCellLength
            Layout.preferredHeight: root.vertical ? root.panelCellLength : -1
            iconSize: tasksGrid.itemSize
            visible: hiddenModel.count > 0 || activeModel.count > 0
            DropArea {
                anchors.fill: parent
                keys: ["application/x-controlhub-tray-id"]
                onEntered: revealTimer.restart()
                onExited: revealTimer.stop()
                onDropped: drop => {
                    revealTimer.stop();
                    const id = drop.getDataAsString("application/x-controlhub-tray-id") || drop.source?.itemId;
                    if (id) {
                        root.setTrayVisibility(id, "hidden");
                        drop.acceptProposedAction();
                    }
                }
            }
            Timer { id: revealTimer; interval: 450; onTriggered: root.showHome("applications") }
        }
        PanelButton {
            id: controlsButton
            objectName: "controlsButton"
            Layout.fillWidth: root.vertical
            Layout.fillHeight: !root.vertical
            Layout.preferredWidth: root.vertical ? -1 : root.panelCellLength
            Layout.preferredHeight: root.vertical ? root.panelCellLength : -1
            iconSize: tasksGrid.itemSize
            glyphSource: Qt.resolvedUrl("icons/hub-control-center.svg")
            text: i18n("Control Center")
            checked: systemTrayState.expanded && root.popupMode === "controls"
            onClicked: root.toggleHome("controls")
        }
        PanelButton {
            id: notificationsButton
            objectName: "notificationsButton"
            Layout.fillWidth: root.vertical
            Layout.fillHeight: !root.vertical
            Layout.preferredWidth: root.vertical ? -1 : root.panelCellLength
            Layout.preferredHeight: root.vertical ? root.panelCellLength : -1
            iconSize: tasksGrid.itemSize
            glyphSource: root.notificationsApplet?.inhibitedOrBroken
                ? Qt.resolvedUrl("icons/hub-notifications-paused.svg")
                : Qt.resolvedUrl("icons/hub-notifications.svg")
            text: root.unreadCount > 0 ? i18np("%1 unread notification", "%1 unread notifications", root.unreadCount) : i18n("Notifications")
            checked: root.notificationsOpen
            enabled: root.notificationsApplet !== null
            onClicked: {
                if (root.notificationsOpen) root.notificationsOpen = false;
                else root.openNotifications();
            }
            Kirigami.Badge {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: Math.max(0, (notificationsButton.height - notificationsButton.iconSize) / 2 - height / 3)
                visible: root.unreadCount > 0
                text: root.unreadCount > 99 ? "99+" : root.unreadCount
            }
        }
    }

    PlasmaCore.AppletPopup {
        id: dialog
        objectName: "controlPopup"
        visualParent: root
        popupDirection: switch (Plasmoid.location) {
            case PlasmaCore.Types.TopEdge: return Qt.BottomEdge;
            case PlasmaCore.Types.LeftEdge: return Qt.RightEdge;
            case PlasmaCore.Types.RightEdge: return Qt.LeftEdge;
            default: return Qt.TopEdge;
        }
        margin: (Plasmoid.containmentDisplayHints & PlasmaCore.Types.ContainmentPrefersFloatingApplets) ? Kirigami.Units.largeSpacing : 0
        floating: Plasmoid.location === PlasmaCore.Types.Desktop
        hideOnWindowDeactivate: !Plasmoid.configuration.pin
        visible: systemTrayState.expanded
        appletInterface: root
        backgroundHints: (Plasmoid.containmentDisplayHints & PlasmaCore.Types.ContainmentPrefersOpaqueBackground) ? PlasmaCore.AppletPopup.SolidBackground : PlasmaCore.AppletPopup.StandardBackground
        onVisibleChanged: {
            if (!visible) systemTrayState.expanded = false;
            else { requestActivate(); expandedRepresentation.forceActiveFocus(); }
        }
        mainItem: ExpandedRepresentation {
            id: expandedRepresentation
            Keys.onEscapePressed: {
                if (root.editing) root.editing = false;
                else if (systemTrayState.activeApplet) systemTrayState.setActiveApplet(null);
                else systemTrayState.expanded = false;
            }
            Item { id: preloadedStorage; visible: false }
        }
    }

    NotificationDrawer {
        id: notificationDrawer
        objectName: "notificationDrawer"
        visualParent: root
        appletInterface: root
        animationEnabled: Kirigami.Units.longDuration > 0
        visible: root.notificationsOpen
        backgroundHints: (Plasmoid.containmentDisplayHints & PlasmaCore.Types.ContainmentPrefersOpaqueBackground) ? PlasmaCore.Dialog.SolidBackground : PlasmaCore.Dialog.StandardBackground
        onVisibleChanged: {
            if (!visible) {
                root.notificationsOpen = false;
                if (root.notificationsApplet) root.notificationsApplet.expanded = false;
            } else {
                notificationDrawer.activateDrawer();
                notificationContent.adopt();
                notificationContent.forceActiveFocus();
            }
        }
        mainItem: NotificationContent {
            id: notificationContent
            applet: root.notificationsApplet
            // Native dialog margins can change while its Wayland surface is
            // being resized. Apply after that update to avoid a size feedback loop.
            Binding on width {
                value: Math.max(1, Math.min(Kirigami.Units.gridUnit * 24, notificationDrawer.availableGeometry.width - notificationDrawer.margins.left - notificationDrawer.margins.right))
                delayed: true
            }
            Binding on height {
                value: Math.max(1, notificationDrawer.availableGeometry.height - notificationDrawer.margins.top - notificationDrawer.margins.bottom)
                delayed: true
            }
            onCloseRequested: root.notificationsOpen = false
        }
    }
}
