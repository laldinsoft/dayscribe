# Changelog

## 0.3.0 — 2026-09-17

- Intel Mac support. `make build` now produces a universal app: Apple Silicon
  keeps Metal GPU inference, and Intel transcribes on the CPU with Accelerate
  and AVX2/FMA kernels. `scripts/bootstrap.sh` builds the whisper.cpp engine
  once per architecture and merges the static libraries with `lipo`.
- `make build ARCH=host|arm64|x86_64` builds a single architecture, and
  `scripts/smoke-test.sh --arch x86_64` runs the Intel slice through Rosetta 2
  on an Apple Silicon Mac.
- `scripts/package.sh` names its ZIP after what it built, so the default is now
  `dist/DayScribe-macOS-universal.zip`.
- CI runs the unit tests on Apple Silicon and Intel runners, and builds and
  smoke-tests the app on both.
- Downloadable releases. `make release` signs the universal app with
  Laldinsoft's Developer ID, notarizes and staples it, and wraps it in a
  notarized drag-to-Applications `dist/DayScribe.dmg`. Pushing a `v*` tag runs
  the same script in GitHub Actions and publishes the DMG to a GitHub Release,
  and the README links to the latest one.
- Signing with a real identity now adds a secure timestamp, which notarization
  requires.

## 0.2.0 — 2026-09-15

- Launch at Login via ServiceManagement, with the menu state refreshed each
  time the menu opens, plus `--enable-login`, `--disable-login` and
  `--login-status` command-line flags for scripting.
- `scripts/package.sh` produces a self-contained `dist/DayScribe-macOS-arm64.zip`
  with a SHA-256 sidecar for copying to another Apple Silicon Mac.
- Verified: extracted ZIP passes strict code-signature checks and transcribes
  the sample with all network access denied by a macOS sandbox.

## 0.1.0 — 2026-09-15

- Menu bar app with a Control–Option–N global shortcut (Carbon hotkey, so no
  Accessibility or Input Monitoring permission is needed).
- Local transcription with statically linked whisper.cpp v1.9.4 and the
  `small.en` model, using Metal and Accelerate on Apple Silicon.
- Append-only daily Markdown notes in `~/Documents/Dictation/` with an
  exclusive file lock, fsync before audio deletion, and midnight rollover
  based on when recording started.
- Failed or interrupted recordings are preserved in `~/Documents/Dictation/failed/`.
- 12 unit tests covering the notes writer and recording store, and a smoke
  test that runs real inference on whisper.cpp's bundled JFK sample.
