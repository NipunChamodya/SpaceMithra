#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p dist
build_directory="${1:-build}"
./scripts/build-universal.sh "$build_directory"
app="$build_directory/Build/Products/Release/SpaceMithra.app"
codesign --force --sign - "$app"
codesign --verify --strict "$app"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")"
archive="dist/SpaceMithra-$version-macos-universal.zip"
ditto -c -k --sequesterRsrc --keepParent "$app" "$archive"
shasum -a 256 "$archive" > "dist/SHA256SUMS-$version.txt"
