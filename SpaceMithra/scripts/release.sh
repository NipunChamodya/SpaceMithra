#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p dist
xcodebuild -project SpaceMithra.xcodeproj -scheme SpaceMithra \
  -configuration Release -derivedDataPath build ARCHS='arm64 x86_64' \
  ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO build
app='build/Build/Products/Release/SpaceMithra.app'
codesign --force --sign - "$app"
codesign --verify --strict "$app"
lipo -info "$app/Contents/MacOS/SpaceMithra"
ditto -c -k --sequesterRsrc --keepParent "$app" dist/SpaceMithra-0.1.0-macos-universal.zip
shasum -a 256 dist/SpaceMithra-0.1.0-macos-universal.zip > dist/SHA256SUMS.txt
