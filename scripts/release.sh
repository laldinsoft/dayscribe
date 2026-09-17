#!/bin/bash
# Builds a Developer ID signed, notarized and stapled universal DayScribe.app,
# wraps it in a drag-to-Applications disk image, and notarizes that too, so the
# download opens with a plain double-click on any Mac.
#
# Signing: DAYSCRIBE_SIGNING_IDENTITY, or the only "Developer ID Application"
# identity in the keychain.
# Notarization, either:
#   DAYSCRIBE_NOTARY_PROFILE  a `notarytool store-credentials` profile
#                             (default: dayscribe-notary), or
#   DAYSCRIBE_NOTARY_KEY, DAYSCRIBE_NOTARY_KEY_ID, DAYSCRIBE_NOTARY_ISSUER
#                             an App Store Connect API key (.p8 path), for CI.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/lib.sh

if [[ -z "${DAYSCRIBE_SIGNING_IDENTITY:-}" ]]; then
    IDENTITIES="$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application: .*\)"/\1/p' | sort -u)"
    case "$(printf '%s' "$IDENTITIES" | grep -c .)" in
        1) DAYSCRIBE_SIGNING_IDENTITY="$IDENTITIES" ;;
        0) echo "No Developer ID Application certificate in the keychain." >&2; exit 1 ;;
        *) echo "Several Developer ID identities found; set DAYSCRIBE_SIGNING_IDENTITY to one of:" >&2
           echo "$IDENTITIES" >&2; exit 1 ;;
    esac
fi
export DAYSCRIBE_SIGNING_IDENTITY
[[ "$DAYSCRIBE_SIGNING_IDENTITY" == "Developer ID Application:"* ]] || {
    echo "Releases must be signed with a Developer ID Application identity, not '$DAYSCRIBE_SIGNING_IDENTITY'." >&2
    exit 1
}

if [[ -n "${DAYSCRIBE_NOTARY_KEY:-}" ]]; then
    NOTARY_AUTH=(--key "$DAYSCRIBE_NOTARY_KEY"
                 --key-id "${DAYSCRIBE_NOTARY_KEY_ID:?DAYSCRIBE_NOTARY_KEY_ID is required with DAYSCRIBE_NOTARY_KEY}"
                 --issuer "${DAYSCRIBE_NOTARY_ISSUER:?DAYSCRIBE_NOTARY_ISSUER is required with DAYSCRIBE_NOTARY_KEY}")
else
    NOTARY_AUTH=(--keychain-profile "${DAYSCRIBE_NOTARY_PROFILE:-dayscribe-notary}")
fi
# Fail before a long build if the credentials are wrong.
xcrun notarytool history "${NOTARY_AUTH[@]}" >/dev/null

# notarize FILE: uploads FILE, waits for Apple's verdict, and prints the log on failure.
notarize() {
    local file="$1" result id
    echo "Submitting $(basename "$file") for notarization (this uploads ~$(du -sh "$file" | cut -f1))…"
    result="$(xcrun notarytool submit "$file" "${NOTARY_AUTH[@]}" --wait --output-format plist)" || true
    id="$(/usr/libexec/PlistBuddy -c 'Print :id' /dev/stdin <<< "$result" 2>/dev/null || true)"
    if [[ "$(/usr/libexec/PlistBuddy -c 'Print :status' /dev/stdin <<< "$result" 2>/dev/null)" != Accepted ]]; then
        echo "Notarization failed for $(basename "$file")." >&2
        echo "$result" >&2
        [[ -z "$id" ]] || xcrun notarytool log "$id" "${NOTARY_AUTH[@]}" >&2
        exit 1
    fi
    echo "Notarized (submission $id)."
}

unset DAYSCRIBE_ARCHS  # a release is always universal
./scripts/build.sh

APP="$PWD/dist/DayScribe.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
for arch in arm64 x86_64; do
    lipo "$APP/Contents/MacOS/DayScribe" -verify_arch "$arch" || {
        echo "The release app has no $arch slice." >&2; exit 1
    }
done

WORK="$PWD/.build/release-staging"
rm -rf "$WORK"
mkdir -p "$WORK/dmg"

# Notarize and staple the app itself, so it opens even offline once copied out
# of the disk image.
ditto -c -k --sequesterRsrc --keepParent "$APP" "$WORK/DayScribe.zip"
notarize "$WORK/DayScribe.zip"
xcrun stapler staple "$APP"

# The disk image keeps a stable name so the README can link to
# releases/latest/download/DayScribe.dmg.
DMG="$PWD/dist/DayScribe.dmg"
rm -f "$DMG" "$DMG.sha256"
ditto "$APP" "$WORK/dmg/DayScribe.app"
ln -s /Applications "$WORK/dmg/Applications"
hdiutil create -volname "DayScribe $VERSION" -srcfolder "$WORK/dmg" -fs HFS+ -format ULFO -ov "$DMG"
/usr/bin/codesign --force --sign "$DAYSCRIBE_SIGNING_IDENTITY" --timestamp "$DMG"
notarize "$DMG"
xcrun stapler staple "$DMG"

# Check exactly what a downloader's Gatekeeper will check.
xcrun stapler validate "$APP"
xcrun stapler validate "$DMG"
spctl --assess --type execute --verbose=2 "$APP"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"

(cd dist && shasum -a 256 DayScribe.dmg > DayScribe.dmg.sha256)
rm -rf "$WORK"
echo "Release $VERSION ready: $DMG"
