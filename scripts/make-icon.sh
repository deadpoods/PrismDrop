#!/bin/zsh
set -euo pipefail
project_dir=${0:A:h:h}
iconset_dir=$(mktemp -d)/PrismDrop.iconset
mkdir -p "$iconset_dir"
trap 'rm -rf "${iconset_dir:h}"' EXIT
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$project_dir/Assets/PrismDrop.png" \
    --out "$iconset_dir/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" "$project_dir/Assets/PrismDrop.png" \
    --out "$iconset_dir/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset_dir" -o "$project_dir/Assets/PrismDrop.icns"
echo "Created Assets/PrismDrop.icns"
