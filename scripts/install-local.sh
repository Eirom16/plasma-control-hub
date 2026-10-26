#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
build_dir="${CONTROLHUB_BUILD_DIR:-$project_dir/build}"
install_prefix="${CONTROLHUB_PREFIX:-$HOME/.local}"
stage_dir="$(mktemp -d)"
trap 'rm -rf -- "$stage_dir"' EXIT
DESTDIR="$stage_dir" cmake --install "$build_dir" --prefix "$install_prefix"
# Replace loaded libraries atomically, so a running Plasma session can keep
# using its old mapping until it is restarted.
python3 - "$stage_dir$install_prefix" "$install_prefix" <<'PY'
from pathlib import Path
import os, shutil, sys, tempfile
source_root, destination_root = map(Path, sys.argv[1:])
for source in source_root.rglob('*'):
    if not source.is_file():
        continue
    destination = destination_root / source.relative_to(source_root)
    destination.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix='.' + destination.name, dir=destination.parent)
    os.close(descriptor)
    try:
        shutil.copy2(source, temporary)
        os.replace(temporary, destination)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
PY
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
