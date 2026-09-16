#!/bin/bash
# Transcribes whisper.cpp's bundled sample with the built app.
# Pass --arch x86_64 on an Apple Silicon Mac to exercise the Intel slice
# through Rosetta 2 (or --arch arm64 to force the native one).
set -euo pipefail
cd "$(dirname "$0")/.."
APP="$PWD/dist/DayScribe.app/Contents/MacOS/DayScribe"
[[ -x "$APP" ]] || { echo "Run scripts/build.sh first." >&2; exit 1; }

RUN=()
if [[ "${1:-}" == --arch ]]; then
    ARCH="${2:?--arch needs an architecture}"
    lipo -archs "$APP" | grep -qw "$ARCH" || {
        echo "The built app has no $ARCH slice (it has: $(lipo -archs "$APP"))." >&2
        exit 1
    }
    RUN=(arch "-$ARCH")
    echo "Running the $ARCH slice."
fi

OUTPUT="$(${RUN[@]+"${RUN[@]}"} "$APP" --transcribe "$PWD/.vendor/whisper.cpp/samples/jfk.wav")"
echo "$OUTPUT"
[[ "$OUTPUT" == *"ask not what your country can do for you"* ]] || {
    echo "Unexpected sample transcription." >&2
    exit 1
}
echo "Real local transcription passed. No microphone or daily notes were used."
