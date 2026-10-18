#!/bin/zsh
set -euo pipefail
pkill -x PrismDrop >/dev/null 2>&1 || true
rm -rf "$HOME/Applications/PrismDrop.app"
echo "Removed $HOME/Applications/PrismDrop.app"
echo "Optional: remove PrismDrop entries in System Settings > Privacy & Security."
