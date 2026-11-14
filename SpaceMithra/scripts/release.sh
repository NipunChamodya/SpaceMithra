#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p dist
build_directory="${1:-build}"
xcodebuild -project SpaceMithra.xcodeproj -scheme SpaceMithra \
  -configuration Release -derivedDataPath "$build_directory" ARCHS='arm64 x86_64' \
  ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO build
app="$build_directory/Build/Products/Release/SpaceMithra.app"
codesign --force --sign - "$app"
codesign --verify --strict "$app"
lipo -info "$app/Contents/MacOS/SpaceMithra"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")"
archive="dist/SpaceMithra-$version-macos-universal.zip"
ditto -c -k --sequesterRsrc --keepParent "$app" "$archive"
shasum -a 256 "$archive" > "dist/SHA256SUMS-$version.txt"
