# Changelog

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
