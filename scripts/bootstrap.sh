#!/bin/bash
# Prepares everything the Swift build needs, downloading only pinned,
# checksum-verified artifacts:
#   1. whisper.cpp source (extracted into .vendor/)
#   2. CMake, installed into ./.tools/ only if none is on PATH
#   3. the whisper/ggml static libraries, one build per architecture in
#      .build/native/<arch>/, merged into universal archives in
#      .build/native/lib/
#   4. the Whisper small.en model (models/), unless --engine-only is passed
# Nothing is installed outside this directory.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
source scripts/lib.sh

ENGINE_ONLY=""
[[ "${1:-}" == --engine-only ]] && ENGINE_ONLY=1
ARCHS="$(resolve_archs)"

[[ "$(uname -s)" == Darwin ]] || { echo "DayScribe only builds on macOS." >&2; exit 1; }
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

# build_engine ARCH -> static libraries in .build/native/ARCH/
# Apple Silicon runs inference on the GPU through Metal. Intel Macs have no
# Metal GPU family that ggml's kernels can use, so they run on the CPU with
# Accelerate plus the SIMD extensions every Intel Mac that supports macOS 14
# has (Haswell and later: AVX2, FMA, F16C, BMI2).
build_engine() {
    local arch="$1" backend=()
    if [[ "$arch" == arm64 ]]; then
        xcrun --find metal >/dev/null 2>&1 || {
            echo "Building the Apple Silicon engine needs Metal's shader compiler, which" >&2
            echo "ships with Xcode (the Command Line Tools alone do not include it)." >&2
            echo "Install Xcode, or build only for this Mac with: make build ARCH=host" >&2
            exit 1
        }
        backend=(-DGGML_METAL=ON -DGGML_METAL_EMBED_LIBRARY=ON)
    else
        backend=(-DGGML_METAL=OFF -DGGML_SSE42=ON -DGGML_AVX=ON -DGGML_AVX2=ON
                 -DGGML_FMA=ON -DGGML_F16C=ON -DGGML_BMI2=ON)
    fi
    echo "Building the whisper.cpp engine for ${arch}…"
    "$CMAKE" -S .vendor/whisper.cpp -B ".build/native/$arch" \
        -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_ARCHITECTURES="$arch" -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
        -DBUILD_SHARED_LIBS=OFF -DWHISPER_BUILD_TESTS=OFF -DWHISPER_BUILD_EXAMPLES=OFF \
        -DWHISPER_BUILD_SERVER=OFF -DWHISPER_CURL=OFF -DWHISPER_BUILD_IS_DEV=OFF \
        -DGGML_BLAS=ON -DGGML_NATIVE=OFF -DGGML_OPENMP=OFF -DGGML_CCACHE=OFF -DGGML_BACKEND_DL=OFF \
        "${backend[@]}"
    "$CMAKE" --build ".build/native/$arch" --config Release --target whisper \
        --parallel "$(sysctl -n hw.logicalcpu)"
}

# An architecture that skips a backend still needs an archive to link against,
# so it contributes an empty slice instead of a missing one.
stub_library() {
    local arch="$1" dir=".build/native/$arch/stub"
    if [[ ! -f "$dir/libstub.a" ]]; then
        mkdir -p "$dir"
        : > "$dir/stub.c"
        xcrun clang -c -arch "$arch" -o "$dir/stub.o" "$dir/stub.c"
        xcrun ar rcs "$dir/libstub.a" "$dir/stub.o"
    fi
    echo "$dir/libstub.a"
}

# merge_library NAME -> .build/native/lib/libNAME.a covering every architecture.
merge_library() {
    local name="$1" arch found slices=()
    for arch in $ARCHS; do
        found="$(find ".build/native/$arch" -name "lib$name.a" -print -quit)"
        slices+=("${found:-$(stub_library "$arch")}")
    done
    lipo -create "${slices[@]}" -output ".build/native/lib/lib$name.a"
}

for arch in $ARCHS; do build_engine "$arch"; done

rm -rf .build/native/lib
mkdir -p .build/native/lib
for name in whisper ggml ggml-base ggml-cpu ggml-blas ggml-metal; do merge_library "$name"; done
echo "Engine ready for $(archs_label "$ARCHS"): .build/native/lib"

if [[ -z "$ENGINE_ONLY" ]]; then
    ./scripts/fetch-model.sh
fi
