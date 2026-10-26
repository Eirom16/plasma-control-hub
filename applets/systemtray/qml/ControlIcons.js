// SPDX-FileCopyrightText: 2026 Eirom16
// SPDX-License-Identifier: GPL-2.0-or-later
.pragma library

function fallback(id) {
    const icons = {
        "org.kde.plasma.networkmanagement": "wifi",
        "org.kde.plasma.bluetooth": "bluetooth",
        "org.kde.plasma.volume": "volume",
        "org.kde.plasma.brightness": "brightness",
        "org.kde.plasma.battery": "battery",
        "org.kde.plasma.clipboard": "clipboard",
        "org.kde.plasma.devicenotifier": "devices",
        "org.kde.plasma.mediacontroller": "media",
        "org.kde.kdeconnect": "phone",
        "org.kde.plasma.keyboardlayout": "keyboard",
        "org.kde.plasma.keyboardindicator": "keyboard",
        "org.kde.kscreen": "display",
        "org.kde.plasma.notifications": "notifications",
        "org.kde.plasma.manage-inputmethod": "input-method",
        "org.kde.plasma.kimpanel": "input-method",
        "org.kde.plasma.dwellclicker": "dwell-click",
        "org.kde.plasma.addons.katesessions": "sessions",
        "org.kde.plasma.cameraindicator": "camera",
        "org.kde.plasma.weather": "weather",
        "org.kde.plasma.trash": "trash",
        "org.kde.plasma.diskquota": "disk"
    };
    return icons[id] || "control-center";
}
