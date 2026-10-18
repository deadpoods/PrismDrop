#!/bin/zsh
set -euo pipefail
project_dir=${0:A:h:h}
app_dir="$project_dir/build/PrismDrop.app"
zsh -n "$project_dir/build.sh" "$project_dir/install.sh" "$project_dir/uninstall.sh" \
  "$project_dir/scripts/make-icon.sh" "$project_dir/scripts/package.sh" \
  "$project_dir/scripts/verify.sh" "$project_dir/scripts/render-docs.sh" \
  "$project_dir/scripts/test.sh" "$project_dir/scripts/render-studio.sh"
plutil -lint "$project_dir/Info.plist" "$app_dir/Contents/Info.plist"
lipo "$app_dir/Contents/MacOS/PrismDrop" -verify_arch x86_64 arm64
codesign --verify --deep --strict --verbose=1 "$app_dir"
[[ -s "$app_dir/Contents/Resources/PrismDrop.icns" ]]
cmp "$project_dir/Assets/PrismDrop.icns" "$app_dir/Contents/Resources/PrismDrop.icns"
echo "Verified universal app, configuration, scripts, signature, and icon"
