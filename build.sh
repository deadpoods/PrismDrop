#!/bin/zsh
set -euo pipefail
project_dir=${0:A:h}
build_dir="$project_dir/build"
app_dir="$build_dir/PrismDrop.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
for architecture in x86_64 arm64; do
  swiftc -parse-as-library -O -target "${architecture}-apple-macosx14.0" \
    -framework AppKit -framework SwiftUI -framework ScreenCaptureKit \
    "$project_dir/Source/PrismDrop.swift" \
    -o "$build_dir/PrismDrop-$architecture"
done
lipo -create "$build_dir/PrismDrop-x86_64" "$build_dir/PrismDrop-arm64" \
  -output "$app_dir/Contents/MacOS/PrismDrop"
cp "$project_dir/Info.plist" "$app_dir/Contents/Info.plist"
cp "$project_dir/Assets/PrismDrop.icns" "$app_dir/Contents/Resources/PrismDrop.icns"
# Ad-hoc sign the local app. Rebuilds can change the identity used by privacy grants.
codesign --force --deep --sign - --identifier local.prismdrop.app "$app_dir"
echo "Built $app_dir"
