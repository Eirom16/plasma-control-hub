// SPDX-FileCopyrightText: 2026 Eirom16
// SPDX-License-Identifier: GPL-2.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid

PlasmaComponents.ScrollView {
    id: center
    required property var hub
    readonly property var entries: hub.controlEntries.filter(entry => hub.editing || Plasmoid.configuration.selectedControls.includes(entry.id))
    contentWidth: availableWidth
    QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff
    background: null
    clip: true
    ColumnLayout {
        width: center.availableWidth
        spacing: Kirigami.Units.largeSpacing
        PlasmaComponents.Label {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            visible: center.hub.editing
            text: i18n("Add or remove controls. Drag a row to reorder it, or use the arrow buttons.")
            wrapMode: Text.Wrap
        }
        GridLayout {
            Layout.fillWidth: true
            uniformCellWidths: true
            columns: width >= Kirigami.Units.gridUnit * 22 ? 2 : 1
            columnSpacing: Kirigami.Units.smallSpacing
            rowSpacing: Kirigami.Units.smallSpacing
            visible: !center.hub.editing
            Repeater {
                model: center.hub.editing ? [] : center.entries.filter(entry => entry.id !== "org.kde.plasma.volume" && entry.id !== "org.kde.plasma.brightness")
                delegate: ControlTile {
                    required property var modelData
                    entry: modelData
                    hub: center.hub
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            visible: center.hub.editing
            spacing: Kirigami.Units.smallSpacing
            Repeater {
                model: center.hub.editing ? center.entries : []
                delegate: PlasmaComponents.ItemDelegate {
                    id: row
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    property string controlId: modelData.id
                    objectName: "controlRow_" + controlId
                    readonly property bool fixedControl: controlId === "org.kde.plasma.volume" || controlId === "org.kde.plasma.brightness"
                    Drag.active: false
                    Drag.source: row
                    Drag.keys: ["org.eirom.controlhub.control"]
                    Drag.hotSpot.x: reorder.centroid.position.x
                    Drag.hotSpot.y: reorder.centroid.position.y
                    DragHandler {
                        id: reorder
                        enabled: !row.fixedControl
                        target: null
                        acceptedButtons: Qt.LeftButton
                        onActiveChanged: {
                            if (active) row.Drag.active = true;
                            else row.Drag.drop();
                        }
                    }
                    DropArea {
                        anchors.fill: parent
                        keys: ["org.eirom.controlhub.control"]
                        enabled: !row.fixedControl
                        onDropped: drop => {
                            if (drop.source?.controlId && drop.source.controlId !== row.controlId) {
                                center.hub.moveControl(drop.source.controlId, row.controlId);
                                drop.acceptProposedAction();
                            }
                        }
                    }
                    contentItem: RowLayout {
                        spacing: Kirigami.Units.smallSpacing
                        Kirigami.Icon {
                            source: row.fixedControl ? "object-locked" : "drag-handle-symbolic"
                            Layout.preferredWidth: Kirigami.Units.iconSizes.small
                            Layout.preferredHeight: Kirigami.Units.iconSizes.small
                        }
                        Kirigami.Icon {
                            source: row.modelData.icon
                            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                        }
                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            text: row.fixedControl ? i18n("%1 (bottom)", row.modelData.title) : row.modelData.title
                            elide: Text.ElideRight
                        }
                        PlasmaComponents.ToolButton {
                            icon.name: "go-up-symbolic"
                            text: i18n("Move %1 up", row.modelData.title)
                            display: PlasmaComponents.AbstractButton.IconOnly
                            enabled: !row.fixedControl && row.index > 0
                            onClicked: center.hub.moveControl(row.controlId, center.entries[row.index - 1].id)
                            PlasmaComponents.ToolTip { text: parent.text }
                        }
                        PlasmaComponents.ToolButton {
                            icon.name: "go-down-symbolic"
                            text: i18n("Move %1 down", row.modelData.title)
                            display: PlasmaComponents.AbstractButton.IconOnly
                            enabled: !row.fixedControl && row.index < center.entries.length - 1
                            onClicked: center.hub.moveControl(center.entries[row.index + 1].id, row.controlId)
                            PlasmaComponents.ToolTip { text: parent.text }
                        }
                        PlasmaComponents.CheckBox {
                            text: i18n("Show")
                            Accessible.name: i18n("Show %1", row.modelData.title)
                            checked: Plasmoid.configuration.selectedControls.includes(row.controlId)
                            onToggled: center.hub.setControlVisible(row.controlId, checked)
                        }
                    }
                }
            }
            PlasmaComponents.Button {
                text: i18n("Restore default layout")
                icon.name: "edit-undo"
                onClicked: {
                    Plasmoid.configuration.selectedControls = ["org.kde.plasma.networkmanagement", "org.kde.plasma.bluetooth", "org.kde.plasma.volume", "org.kde.plasma.brightness", "org.kde.plasma.battery", "org.kde.plasma.clipboard", "org.kde.plasma.devicenotifier", "org.kde.plasma.mediacontroller"];
                    Plasmoid.configuration.controlOrder = ["org.kde.plasma.networkmanagement", "org.kde.plasma.bluetooth", "org.kde.plasma.volume", "org.kde.plasma.brightness", "org.kde.plasma.battery", "org.kde.plasma.clipboard", "org.kde.plasma.devicenotifier", "org.kde.plasma.mediacontroller"];
                }
            }
        }
        Kirigami.PlaceholderMessage {
            Layout.fillWidth: true
            visible: center.entries.length === 0
            text: i18n("No controls selected")
            explanation: i18n("Use Edit to add controls to this panel.")
            icon.name: "preferences-system"
        }
    }
}
