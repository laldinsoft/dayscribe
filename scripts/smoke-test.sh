#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
APP="$PWD/dist/DayScribe.app/Contents/MacOS/DayScribe"
[[ -x "$APP" ]] || { echo "Run scripts/build.sh first." >&2; exit 1; }
OUTPUT="$("$APP" --transcribe "$PWD/.vendor/whisper.cpp/samples/jfk.wav")"
echo "$OUTPUT"
[[ "$OUTPUT" == *"ask not what your country can do for you"* ]] || {
    echo "Unexpected sample transcription." >&2
    exit 1
}
echo "Real local transcription passed. No microphone or daily notes were used."
