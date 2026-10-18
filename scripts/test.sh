#!/bin/zsh
set -euo pipefail
project_dir=${0:A:h:h}
mkdir -p "$project_dir/build"
sed '/^@main$/,$d' "$project_dir/Source/PrismDrop.swift" > "$project_dir/build/CombinedTests.swift"
cat "$project_dir/Tests/FeatureTests.swift" "$project_dir/Tests/PickerRegression.swift" >> "$project_dir/build/CombinedTests.swift"
swiftc -parse-as-library -O -framework AppKit -framework SwiftUI -framework ImageIO \
  "$project_dir/Source/ColorCore.swift" "$project_dir/Source/ColorLibrary.swift" \
  "$project_dir/Source/PaletteExtractor.swift" "$project_dir/Source/StudioStore.swift" \
  "$project_dir/Source/StudioView.swift" "$project_dir/build/CombinedTests.swift" \
  -o "$project_dir/build/FeatureTests"
"$project_dir/build/FeatureTests"
