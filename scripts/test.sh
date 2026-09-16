#!/bin/bash
# Unit tests run on this Mac, so only this Mac's architecture is needed.
set -euo pipefail
cd "$(dirname "$0")/.."
DAYSCRIBE_ARCHS="${DAYSCRIBE_ARCHS:-host}" ./scripts/bootstrap.sh --engine-only
swift test
