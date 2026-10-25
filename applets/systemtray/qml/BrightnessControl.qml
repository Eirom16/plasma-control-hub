// SPDX-FileCopyrightText: 2026 Eirom16
// SPDX-License-Identifier: GPL-2.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.private.brightnesscontrolplugin as Brightness

ColumnLayout {
    id: brightness
    objectName: "brightnessControl"
    property var hub: null
    Brightness.ScreenBrightnessControl { id: controller; isSilent: true }
    Repeater {
        model: controller.displays
        delegate: RowLayout {
            id: display
            required property string displayName
            required property string label
            required property int brightness
            required property int maxBrightness
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            Kirigami.Icon {
                source: "brightness-high-symbolic"
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                Accessible.name: display.label
            }
            PlasmaComponents.Slider {
                Layout.fillWidth: true
                Accessible.name: i18n("Brightness of %1", display.label)
                from: 0
                to: display.maxBrightness
                value: display.brightness
                stepSize: Math.max(1, display.maxBrightness / 100)
                enabled: display.maxBrightness > 0
                onMoved: controller.setBrightness(display.displayName, Math.round(value))
            }
            PlasmaComponents.Label {
                text: i18n("%1%", display.maxBrightness > 0 ? Math.round(100 * display.brightness / display.maxBrightness) : 0)
                Layout.minimumWidth: Kirigami.Units.gridUnit * 3
                horizontalAlignment: Text.AlignRight
            }
            PlasmaComponents.ToolButton {
                id: displayOptions
                text: i18n("More brightness and color options")
                icon.name: "go-next-symbolic"
                display: PlasmaComponents.AbstractButton.IconOnly
                enabled: !!brightness.hub?.hosts["org.kde.plasma.brightness"]?.applet
                onClicked: brightness.hub.openControl(brightness.hub.hosts["org.kde.plasma.brightness"].applet)
                PlasmaComponents.ToolTip { text: displayOptions.text }
            }
        }
    }
    RowLayout {
        visible: !controller.isBrightnessAvailable
        Layout.fillWidth: true
        Kirigami.Icon {
            source: "brightness-high-symbolic"
            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
        }
        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: i18n("Brightness unavailable")
            enabled: false
        }
        PlasmaComponents.ToolButton {
            id: otherOptions
            text: i18n("More brightness and color options")
            icon.name: "go-next-symbolic"
            display: PlasmaComponents.AbstractButton.IconOnly
            enabled: !!brightness.hub?.hosts["org.kde.plasma.brightness"]?.applet
            onClicked: brightness.hub.openControl(brightness.hub.hosts["org.kde.plasma.brightness"].applet)
            PlasmaComponents.ToolTip { text: otherOptions.text }
        }
    }
}
