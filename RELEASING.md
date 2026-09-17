# Releasing DayScribe

A release is a notarized `DayScribe.dmg` attached to a GitHub Release. The
README's download link points at `releases/latest/download/DayScribe.dmg`, so
publishing a release is all it takes for new downloads to get it.

Signing uses the **Laldinsoft Ltd** team (`A8F2K75G7M`) and its
**Developer ID Application** certificate. That is a different certificate from
the Apple Distribution one Xcode manages for the App Store apps: `codesign`
needs the private key locally, so it cannot be cloud-managed.

## Publishing a release

1. Bump `CFBundleShortVersionString` and `CFBundleVersion` in
   `Resources/Info.plist`.
2. In `CHANGELOG.md`, rename `## Unreleased` to `## X.Y.Z — YYYY-MM-DD`. That
   section becomes the release notes.
3. Commit, then tag and push:

   ```sh
   git tag vX.Y.Z
   git push origin main vX.Y.Z
   ```

The **Release** workflow checks the tag matches `Info.plist`, runs
`scripts/release.sh`, smoke-tests the result, and publishes the release.
Notarization uploads the app twice (the app, then the disk image), so expect
it to take 15–30 minutes.

## Releasing from a Mac instead

With the Developer ID certificate in your keychain and notary credentials
stored once:

```sh
xcrun notarytool store-credentials dayscribe-notary \
  --key AuthKey_XXXXXXXXXX.p8 --key-id XXXXXXXXXX --issuer <issuer id>
make release
```

This produces `dist/DayScribe.dmg` and its `.sha256`, verified with `stapler`
and `spctl` exactly as Gatekeeper will check them. Upload both to a GitHub
Release by hand.

## Repository secrets

| Secret | Value |
| --- | --- |
| `DEVELOPER_ID_P12_BASE64` | The Developer ID certificate and key exported from Keychain Access as `.p12`, then `base64 -i DeveloperID.p12 \| pbcopy` |
| `DEVELOPER_ID_P12_PASSWORD` | The password chosen when exporting the `.p12` |
| `NOTARY_KEY_P8` | The full text of the App Store Connect API key, `AuthKey_XXXXXXXXXX.p8` |
| `NOTARY_KEY_ID` | That key's Key ID |
| `NOTARY_ISSUER_ID` | The Issuer ID shown above the keys list in App Store Connect |

The API key needs the **Developer** role. Keep the `.p12`, its password and
the `.p8` in the company password manager; Apple lets you download a `.p8`
only once.

## Certificate expiry

The current Developer ID certificate expires on **1 February 2027**, capped by
Apple's intermediate authority. Releases already published keep opening after
that, because each is timestamped and notarized. To publish after that date,
create a new Developer ID Application certificate (Xcode → Settings → Accounts
→ Manage Certificates) and replace the two `DEVELOPER_ID_P12_*` secrets.
