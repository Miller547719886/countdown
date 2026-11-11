#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_dir"

configuration=${JIEDIAN_CONFIGURATION:-release}
app_dir="$project_dir/dist/截点.app"
binary="$project_dir/.build/arm64-apple-macosx/$configuration/Jiedian"
resource_bundle="$project_dir/.build/arm64-apple-macosx/$configuration/Jiedian_JiedianApp.bundle"
core_resource_bundle="$project_dir/.build/arm64-apple-macosx/$configuration/Jiedian_JiedianCore.bundle"

swift build -c "$configuration"

rm -rf "$app_dir"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$binary" "$app_dir/Contents/MacOS/Jiedian"
cp "$project_dir/Resources/Info.plist" "$app_dir/Contents/Info.plist"

if [ ! -d "$resource_bundle" ]; then
    printf '%s\n' "Missing app resources: $resource_bundle" >&2
    exit 1
fi
cp -R "$resource_bundle" "$app_dir/Contents/Resources/"

if [ ! -d "$core_resource_bundle" ]; then
    printf '%s\n' "Missing core resources: $core_resource_bundle" >&2
    exit 1
fi
cp -R "$core_resource_bundle" "$app_dir/Contents/Resources/"

if [ -f "$project_dir/Resources/AppIcon.icns" ]; then
    cp "$project_dir/Resources/AppIcon.icns" "$app_dir/Contents/Resources/AppIcon.icns"
fi

cp "$project_dir/THIRD_PARTY_NOTICES.md" "$app_dir/Contents/Resources/THIRD_PARTY_NOTICES.md"
cp "$project_dir/Vendor/Tyme4Swift/LICENSE" "$app_dir/Contents/Resources/Tyme4Swift-LICENSE.txt"

codesign --force --deep --sign - "$app_dir"
printf '%s\n' "Built $app_dir"
