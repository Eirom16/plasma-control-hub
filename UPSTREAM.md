# Upstream provenance

This project derives from KDE Plasma Workspace 6.8.1.

- Source: https://invent.kde.org/plasma/plasma-workspace
- Mirror: https://github.com/KDE/plasma-workspace
- Tag: v6.8.1
- Commit: fb9b679a99078e68164b05b9cb3f5aaa6020222f
- Imported: applets/systemtray, libdbusmenuqt, libkmpris/dbus/org.freedesktop.DBus.Properties.xml, LICENSES.

Original copyright notices and SPDX identifiers are retained per file.
The initial import commit preserves the original sources for review and updates.
Network, Bluetooth, audio, brightness, power and notification applets are loaded
from the installed KDE Plasma distribution; their functionality stays upstream.

- Additional imported header: statusnotifierwatcher/systemtraytypedefs.h (stored alongside systemtraytypes.h).
- Spanish catalogue: `po/es/plasma_applet_org.kde.plasma.systemtray.po` from the same tag, renamed to our domain and extended with the new interface strings. Original translator credits are retained.

- Native shell protocol XML: KDE plasma-wayland-protocols v1.20.0, commit `6fee13b7c0b25d4619e20090f4a178fc2b460be7`, `src/protocols/plasma-shell.xml`. It supplies only the generated headers required by libplasma's installed shell integration API; we reuse libplasma's existing surface and implementation.
