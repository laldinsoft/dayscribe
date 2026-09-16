#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/lib.sh
./scripts/build.sh
NAME="DayScribe-macOS-$(archs_label "$(resolve_archs)").zip"
ARCHIVE="$PWD/dist/$NAME"
rm -f "$ARCHIVE" "$ARCHIVE.sha256"
ditto -c -k --sequesterRsrc --keepParent dist/DayScribe.app "$ARCHIVE"
(cd dist && shasum -a 256 "$NAME" > "$NAME.sha256")
echo "Ready to copy to another Mac ($(lipo -archs dist/DayScribe.app/Contents/MacOS/DayScribe)): $ARCHIVE"
