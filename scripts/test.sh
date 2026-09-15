#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/bootstrap.sh --engine-only
swift test
