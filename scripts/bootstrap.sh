#!/bin/bash
# Prepares everything the Swift build needs, downloading only pinned,
# checksum-verified artifacts:
#   1. whisper.cpp source (extracted into .vendor/)
#   2. CMake, installed into ./.tools/ only if none is on PATH
#   3. the whisper/ggml static libraries (built into .build/native/)
#   4. the Whisper small.en model (models/), unless --engine-only is passed
# Nothing is installed outside this directory.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
source scripts/lib.sh

[[ "$(uname -s)" == Darwin ]] || { echo "DayScribe only builds on macOS." >&2; exit 1; }
[[ "$(uname -m)" == arm64 ]] || { echo "DayScribe requires an Apple Silicon Mac." >&2; exit 1; }
xcrun --find swift >/dev/null || { echo "Install Xcode or the Xcode Command Line Tools first." >&2; exit 1; }
mkdir -p .vendor

WHISPER_VERSION="1.9.4"
WHISPER_SHA256="57e280cee375ab02425b806ad5146b99f6eb9357e3c2b31357c8a6af2e2e44ae"
fetch "https://github.com/ggml-org/whisper.cpp/archive/refs/tags/v$WHISPER_VERSION.tar.gz" \
    ".vendor/whisper-v$WHISPER_VERSION.tar.gz" "$WHISPER_SHA256"
if [[ ! -f .vendor/whisper.cpp/CMakeLists.txt ]]; then
    tar -xzf ".vendor/whisper-v$WHISPER_VERSION.tar.gz" -C .vendor
    mv ".vendor/whisper.cpp-$WHISPER_VERSION" .vendor/whisper.cpp
fi

if command -v cmake >/dev/null; then
    CMAKE="$(command -v cmake)"
else
    if [[ ! -x .tools/bin/cmake ]]; then
        echo "CMake not found; installing a private copy into .tools/ (requires python3)…"
        python3 -m venv .tools
        .tools/bin/python -m pip install --quiet cmake==3.31.6
    fi
    CMAKE="$ROOT/.tools/bin/cmake"
fi

"$CMAKE" -S .vendor/whisper.cpp -B .build/native \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
    -DBUILD_SHARED_LIBS=OFF -DWHISPER_BUILD_TESTS=OFF -DWHISPER_BUILD_EXAMPLES=OFF \
    -DWHISPER_BUILD_SERVER=OFF -DWHISPER_CURL=OFF -DWHISPER_BUILD_IS_DEV=OFF \
    -DGGML_METAL=ON -DGGML_METAL_EMBED_LIBRARY=ON -DGGML_BLAS=ON \
    -DGGML_NATIVE=OFF -DGGML_OPENMP=OFF -DGGML_CCACHE=OFF -DGGML_BACKEND_DL=OFF
"$CMAKE" --build .build/native --config Release --target whisper --parallel "$(sysctl -n hw.logicalcpu)"

if [[ "${1:-}" != --engine-only ]]; then
    ./scripts/fetch-model.sh
fi
