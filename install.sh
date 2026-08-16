#!/bin/bash
# Install power-administrator-plugin into Omarchy and enable it in the bar.

set -euo pipefail

ID="pcrisho.power-admin"
SRC="$(cd "$(dirname "$0")" && pwd)"
TARGET="$HOME/.config/omarchy/plugins/$ID"

fail() {
  echo "install: $*" >&2
  exit 1
}

[[ -f "$SRC/manifest.json" && -f "$SRC/Panel.qml" ]] || fail "manifest.json/Panel.qml missing in $SRC"

echo "Installing $ID -> $TARGET"
mkdir -p "$TARGET"
cp -a "$SRC/manifest.json" "$SRC/Panel.qml" "$TARGET/"

# The shell is sometimes slow to answer IPC; give it room.
export OMARCHY_SHELL_IPC_TIMEOUT="${OMARCHY_SHELL_IPC_TIMEOUT:-15s}"

echo "Rescanning plugins..."
omarchy-shell shell rescanPlugins >/dev/null
sleep 0.5

if ! omarchy-plugin-list --json | jq -e --arg id "$ID" 'any(.[]; .id == $id)' >/dev/null; then
  fail "$ID was not discovered after rescan"
fi

if ! omarchy plugin enable "$ID" --section right >/dev/null; then
  fail "could not enable $ID (is it already enabled?)"
fi

echo "Installed and enabled $ID (right section)."