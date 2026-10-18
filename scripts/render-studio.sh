#!/bin/zsh
set -euo pipefail
project_dir=${0:A:h:h}
mkdir -p "$project_dir/.render-docs"
swiftc -parse-as-library -O -framework AppKit -framework SwiftUI -framework ImageIO \
  "$project_dir/Source/ColorCore.swift" "$project_dir/Source/ColorLibrary.swift" \
  "$project_dir/Source/PaletteExtractor.swift" "$project_dir/Source/StudioStore.swift" \
  "$project_dir/Source/StudioView.swift" "$project_dir/tools/RenderStudio.swift" \
  -o "$project_dir/.render-docs/RenderStudio"
"$project_dir/.render-docs/RenderStudio" "$project_dir"
