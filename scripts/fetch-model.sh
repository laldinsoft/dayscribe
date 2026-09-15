#!/bin/bash
# Downloads the pinned Whisper small.en GGML model (about 488 MB) into models/.
# Safe to re-run: an existing file with the correct checksum is reused.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/lib.sh

MODEL_NAME="ggml-small.en.bin"
MODEL_REVISION="5359861c739e955e79d9a303bcbc70fb988958b1"
MODEL_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/$MODEL_REVISION/$MODEL_NAME"
MODEL_SHA256="c6138d6d58ecc8322097e0f987c32f1be8bb0a18532a3f88f734d1bbf9c41e5d"

mkdir -p models
fetch "$MODEL_URL" "models/$MODEL_NAME" "$MODEL_SHA256"
echo "Model ready: models/$MODEL_NAME"
