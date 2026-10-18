#!/bin/zsh
set -euo pipefail
project_dir=${0:A:h}
built_app="$project_dir/build/PrismDrop.app"
source_changed=false
for source_file in "$project_dir"/Source/*.swift; do
  if [[ "$source_file" -nt "$built_app/Contents/MacOS/PrismDrop" ]]; then source_changed=true; fi
done
if [[ "$source_changed" == true || ! -x "$built_app/Contents/MacOS/PrismDrop" || \
      ! -f "$built_app/Contents/Resources/PrismDrop.icns" || \
      "$project_dir/Info.plist" -nt "$built_app/Contents/Info.plist" || \
      "$project_dir/Assets/PrismDrop.icns" -nt "$built_app/Contents/Resources/PrismDrop.icns" ]]; then
  "$project_dir/build.sh"
else
  echo "Using existing build (preserves its privacy identity)"
fi
mkdir -p "$HOME/Applications"
if [[ -d "$HOME/Applications/PrismDrop.app" ]] && \
   cmp -s "$built_app/Contents/MacOS/PrismDrop" "$HOME/Applications/PrismDrop.app/Contents/MacOS/PrismDrop" && \
   cmp -s "$built_app/Contents/Info.plist" "$HOME/Applications/PrismDrop.app/Contents/Info.plist" && \
   cmp -s "$built_app/Contents/Resources/PrismDrop.icns" "$HOME/Applications/PrismDrop.app/Contents/Resources/PrismDrop.icns"; then
  open "$HOME/Applications/PrismDrop.app"
  echo "Already installed: $HOME/Applications/PrismDrop.app"
  exit 0
fi
if [[ -d "$HOME/Applications/PrismDrop.app" ]]; then
  pkill -x PrismDrop >/dev/null 2>&1 || true
  rm -rf "$HOME/Applications/PrismDrop.app"
fi
ditto "$built_app" "$HOME/Applications/PrismDrop.app"
open "$HOME/Applications/PrismDrop.app"
echo "Installed and opened $HOME/Applications/PrismDrop.app"
