#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
build_dir="${CONTROLHUB_BUILD_DIR:-$project_dir/build}"
install_prefix="${CONTROLHUB_PREFIX:-$HOME/.local}"
cmake --install "$build_dir" --prefix "$install_prefix"
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/plasma-workspace/env"
mkdir -p -- "$config_dir"
plugin_dir="$install_prefix/lib/plugins"
{
    printf '#!/bin/sh\n# Plasma Control Hub: user plugin discovery.\n'
    # bash's %q can produce Bash-only escapes; use Python for POSIX shell quoting.
    python3 - "$plugin_dir" <<'PY'
import shlex, sys
print('export QT_PLUGIN_PATH=' + shlex.quote(sys.argv[1]) + '${QT_PLUGIN_PATH:+:"$QT_PLUGIN_PATH"}')
PY
} > "$config_dir/plasma-control-hub.sh"
chmod 755 -- "$config_dir/plasma-control-hub.sh"
printf 'Instalado. En la siguiente sesión de Plasma añade «Centro de control de Plasma».\n'
