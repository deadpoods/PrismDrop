#!/bin/zsh
set -euo pipefail
project_dir=${0:A:h:h}
app_dir="$project_dir/build/PrismDrop.app"
[[ -x "$app_dir/Contents/MacOS/PrismDrop" ]] || "$project_dir/build.sh"
"$project_dir/scripts/verify.sh"
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app_dir/Contents/Info.plist")
mkdir -p "$project_dir/dist"
archive="PrismDrop-$version-universal.zip"
ditto -c -k --sequesterRsrc --keepParent "$app_dir" "$project_dir/dist/$archive"
cd "$project_dir/dist"
shasum -a 256 "$archive" > "$archive.sha256"
echo "Packaged dist/$archive"
