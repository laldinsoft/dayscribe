#!/bin/bash
# Shared helpers for the DayScribe scripts. Source this file; do not run it.

# Prints the SHA-256 of a file.
sha256() { shasum -a 256 "$1" | awk '{print $1}'; }

# verify FILE CHECKSUM -> exit status 0 when the file matches.
verify() { [[ -f "$1" ]] && [[ "$(sha256 "$1")" == "$2" ]]; }

# fetch URL DESTINATION CHECKSUM
# Downloads to DESTINATION only if it is missing or does not match CHECKSUM.
# A mismatched download is deleted so a corrupt file is never left in place.
fetch() {
    local url="$1" destination="$2" checksum="$3"
    if verify "$destination" "$checksum"; then return; fi
    echo "Downloading $(basename "$destination")…"
    curl --fail --location --retry 3 --progress-bar "$url" --output "$destination.download"
    if ! verify "$destination.download" "$checksum"; then
        rm -f "$destination.download"
        echo "Checksum mismatch for $destination (expected $checksum)." >&2
        exit 1
    fi
    mv "$destination.download" "$destination"
}

# Architectures to build for. Set DAYSCRIBE_ARCHS to "universal" (both, the
# default), "host" (whatever this Mac is), or a space-separated list such as
# "arm64" or "x86_64". Every script resolves it the same way so that a
# bootstrap, a build, and a package always agree on what was produced.
resolve_archs() {
    local request="${DAYSCRIBE_ARCHS:-universal}" arch
    case "$request" in
        universal) request="arm64 x86_64" ;;
        host|native) request="$(uname -m)" ;;
    esac
    for arch in $request; do
        case "$arch" in
            arm64|x86_64) ;;
            *) echo "Unknown architecture '$arch'; use arm64, x86_64, universal, or host." >&2; exit 1 ;;
        esac
    done
    echo $request
}

# The name used for build products: "universal" when both slices are present.
archs_label() {
    local archs="$1"
    if [[ "$archs" == *arm64* && "$archs" == *x86_64* ]]; then echo universal; else echo "$archs"; fi
}
