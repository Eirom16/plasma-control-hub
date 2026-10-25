#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
build_dir="${CONTROLHUB_BUILD_DIR:-$project_dir/build}"
export QT_PLUGIN_PATH="$build_dir/lib${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"
export CONTROLHUB_MANUAL=1
# A private session bus prevents this review window from competing with the
# desktop notification service or showing review notifications on the desktop.
exec dbus-run-session --config-file="$project_dir/tests/session-bus.conf" -- "$build_dir/bin/controlhub-smoke"
