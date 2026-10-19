#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_dir"

configuration=${JIEDIAN_CONFIGURATION:-release}
app_dir="$project_dir/dist/截点.app"
binary="$project_dir/.build/arm64-apple-macosx/$configuration/Jiedian"

swift build -c "$configuration"

rm -rf "$app_dir"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$binary" "$app_dir/Contents/MacOS/Jiedian"
cp "$project_dir/Resources/Info.plist" "$app_dir/Contents/Info.plist"

if [ -f "$project_dir/Resources/AppIcon.icns" ]; then
    cp "$project_dir/Resources/AppIcon.icns" "$app_dir/Contents/Resources/AppIcon.icns"
fi

codesign --force --deep --sign - "$app_dir"
printf '%s\n' "Built $app_dir"
