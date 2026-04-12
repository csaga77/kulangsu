#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
PROJECT_ROOT=${SCRIPT_DIR:h}
GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
LOG_DIR="${PROJECT_ROOT}/.godot/headless_logs"

mkdir -p "${LOG_DIR}"

exec "${GODOT_BIN}" \
	--headless \
	--log-file "${LOG_DIR}/godot-headless.log" \
	--path "${PROJECT_ROOT}" \
	"$@"
