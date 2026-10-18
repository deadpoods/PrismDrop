#!/bin/zsh
set -euo pipefail
project_dir=${0:A:h:h}
render_dir="$project_dir/.render-docs"
mkdir -p "$render_dir" "$project_dir/docs/assets"
# Compile the production view and the documentation entry point in one module.
sed '/^@main$/,$d' "$project_dir/Source/PrismDrop.swift" > "$render_dir/Documentation.swift"
cat "$project_dir/tools/RenderDocumentation.swift" >> "$render_dir/Documentation.swift"
swiftc -parse-as-library -O -framework AppKit -framework SwiftUI -framework ScreenCaptureKit \
  "$render_dir/Documentation.swift" -o "$render_dir/RenderDocumentation"
"$render_dir/RenderDocumentation" "$project_dir"
