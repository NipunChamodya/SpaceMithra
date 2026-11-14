#!/bin/sh
# Shared by CI and release packaging; keep both architectures mandatory.
set -eu
cd "$(dirname "$0")/.."
build_directory="${1:-build}"
xcodebuild -project SpaceMithra.xcodeproj -scheme SpaceMithra \
  -configuration Release -destination 'generic/platform=macOS' \
  -derivedDataPath "$build_directory" ARCHS='arm64 x86_64' \
  ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO build
binary="$build_directory/Build/Products/Release/SpaceMithra.app/Contents/MacOS/SpaceMithra"
for architecture in arm64 x86_64; do
  xcrun lipo "$binary" -verify_arch "$architecture"
done
xcrun lipo -info "$binary"
