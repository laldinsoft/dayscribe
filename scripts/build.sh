#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/lib.sh
ARCHS="$(resolve_archs)"
SWIFT_ARCH_FLAGS=()
for arch in $ARCHS; do SWIFT_ARCH_FLAGS+=(--arch "$arch"); done

./scripts/bootstrap.sh
swift build -c release "${SWIFT_ARCH_FLAGS[@]}"
BIN_DIR="$(swift build -c release "${SWIFT_ARCH_FLAGS[@]}" --show-bin-path)"
APP="$PWD/dist/DayScribe.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/Licenses"
cp "$BIN_DIR/DayScribe" "$APP/Contents/MacOS/DayScribe"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp models/ggml-small.en.bin "$APP/Contents/Resources/ggml-small.en.bin"
cp .vendor/whisper.cpp/LICENSE "$APP/Contents/Resources/Licenses/whisper.cpp.txt"
cp THIRD_PARTY_NOTICES.md "$APP/Contents/Resources/Licenses/THIRD_PARTY_NOTICES.md"
/usr/bin/codesign --force --sign "${DAYSCRIBE_SIGNING_IDENTITY:--}" --options runtime \
    --entitlements Resources/DayScribe.entitlements "$APP"
/usr/bin/codesign --verify --strict "$APP"
echo "Built $APP ($(lipo -archs "$APP/Contents/MacOS/DayScribe"))"
echo "Open it with: open dist/DayScribe.app"
