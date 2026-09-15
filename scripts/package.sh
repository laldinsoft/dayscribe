#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/build.sh
ARCHIVE="$PWD/dist/DayScribe-macOS-arm64.zip"
ditto -c -k --sequesterRsrc --keepParent dist/DayScribe.app "$ARCHIVE"
(cd dist && shasum -a 256 DayScribe-macOS-arm64.zip > DayScribe-macOS-arm64.zip.sha256)
echo "Ready to copy to another Apple Silicon Mac: $ARCHIVE"
