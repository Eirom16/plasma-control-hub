// SPDX-FileCopyrightText: 2026 Eirom16
// SPDX-License-Identifier: GPL-2.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.private.volume as Volume

RowLayout {
    id: audio
    objectName: "volumeControl"
    property var hub: null
    readonly property var sink: Volume.Server.defaultSink
    readonly property int normalVolume: 65536 // PA_VOLUME_NORM, as used by plasma-pa
    spacing: Kirigami.Units.smallSpacing
    PlasmaComponents.ToolButton {
        id: mute
        text: i18n("Mute audio")
        icon.name: audio.sink?.muted ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic"
        display: PlasmaComponents.AbstractButton.IconOnly
        checkable: true
        checked: audio.sink?.muted ?? false
        enabled: audio.sink !== null
        onClicked: if (audio.sink) audio.sink.muted = !audio.sink.muted
        PlasmaComponents.ToolTip { text: mute.text }
    }
    PlasmaComponents.Slider {
        id: volume
        Layout.fillWidth: true
        Accessible.name: i18n("Volume")
        from: 0
        to: audio.normalVolume
        value: audio.sink?.volume ?? 0
        enabled: audio.sink?.volumeWritable ?? false
        stepSize: audio.normalVolume / 100
        onMoved: if (audio.sink) audio.sink.volume = Math.round(value)
    }
    PlasmaComponents.Label {
        text: i18n("%1%", Math.round(volume.value / audio.normalVolume * 100))
        Layout.minimumWidth: Kirigami.Units.gridUnit * 3
        horizontalAlignment: Text.AlignRight
    }
    PlasmaComponents.ToolButton {
        id: audioOptions
        text: i18n("More audio options")
        icon.name: "go-next-symbolic"
        display: PlasmaComponents.AbstractButton.IconOnly
        enabled: !!audio.hub?.hosts["org.kde.plasma.volume"]?.applet
        onClicked: audio.hub.openControl(audio.hub.hosts["org.kde.plasma.volume"].applet)
        PlasmaComponents.ToolTip { text: audioOptions.text }
    }

}
