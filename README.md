# DayScribe

[![CI](https://github.com/laldinsoft/dayscribe/actions/workflows/ci.yml/badge.svg)](https://github.com/laldinsoft/dayscribe/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![Platform](https://img.shields.io/badge/platform-macOS%2014%2B%20Apple%20Silicon%20%26%20Intel-lightgrey)

A tiny, native macOS menu bar utility for capturing voice notes into a daily Markdown file, transcribed entirely on your Mac.

**Control + Option + N → speak → Control + Option + N → note appended to today's Markdown.**

- **Fully local.** Transcription uses a statically linked [whisper.cpp](https://github.com/ggml-org/whisper.cpp), accelerated by Metal on Apple Silicon and by Accelerate and AVX2 on Intel. The app has no networking code, no account, no API key, no telemetry.
- **Plain files.** Notes are appended to `~/Documents/Dictation/YYYY-MM-DD.md`. Nothing else is stored.
- **Stays out of the way.** No window, no Dock icon, one global shortcut that works while other apps have focus.
- **Safe by default.** Audio is deleted only after the note is durably written. Anything that fails is kept for manual recovery.

## Download

**[Download DayScribe for Mac](https://github.com/laldinsoft/dayscribe/releases/latest/download/DayScribe.dmg)** (about 430 MB, macOS 14 or later, Apple Silicon or Intel)

1. Open the downloaded `DayScribe.dmg`.
2. Drag **DayScribe** onto the **Applications** folder in that window.
3. Open DayScribe from Applications (or Launchpad). A microphone icon appears in the menu bar; there is no window.
4. Press **Control + Option + N**, allow microphone access, speak, and press it again. Your note is in `Documents/Dictation`.

The download is signed by Laldinsoft Ltd and notarized by Apple, so it opens normally. Everything, including the speech model, is inside the app: no account, no further downloads, and no internet connection needed after this. To update, download the new version and replace the app in Applications. To uninstall, quit DayScribe from its menu and move it to the Trash.

## Build from source

Requirements: a Mac running macOS 14 or later — Apple Silicon or Intel — and Xcode or the Xcode Command Line Tools. `make build` produces a universal app that runs on both.

```sh
git clone https://github.com/laldinsoft/dayscribe.git
cd dayscribe
make run
```

`make run` downloads the pinned whisper.cpp source and the English `small.en` Whisper model (about 488 MB), builds the native libraries and the app, and opens `dist/DayScribe.app`. Nothing is installed outside the project directory: the model and sources live in `models/` and `.vendor/`, and if CMake is not on your PATH a private copy is installed into `.tools/`. Every download is pinned to a specific release and verified against a SHA-256 checksum before use. Subsequent builds reuse the downloads.

The model is not part of this repository. It is fetched from the [ggerganov/whisper.cpp](https://huggingface.co/ggerganov/whisper.cpp) Hugging Face repository the first time you build.

### Make targets

| Target | What it does |
| --- | --- |
| `make setup` | Download whisper.cpp and build its static libraries. No model download. |
| `make model` | Download the Whisper `small.en` model into `models/`. |
| `make build` | Everything above, then build a universal `dist/DayScribe.app`. |
| `make run` | Build if needed, then open the app. |
| `make test` | Run the unit tests. Does not need the model. |
| `make smoke` | Transcribe whisper.cpp's bundled sample with the built app. |
| `make package` | Build and zip the app for another Mac. |
| `make release` | Build, sign with Developer ID, notarize, and make `dist/DayScribe.dmg`. See [RELEASING.md](RELEASING.md). |
| `make clean` | Remove build output but keep downloads. |
| `make distclean` | Remove build output and all downloads. |

Each target wraps a script in `scripts/`; you can call those directly instead.

The resulting `dist/DayScribe.app` is self-contained and includes the model. You can move it to `~/Applications` or `/Applications`. Choose one location before granting microphone permission. `make build` is ad-hoc signed for local use; set `DAYSCRIBE_SIGNING_IDENTITY` to sign with a certificate instead. Ad-hoc rebuilds may require granting microphone permission again. Published downloads are made with `make release`, which signs with Laldinsoft's Developer ID and notarizes the app and disk image.

### Architectures

`make build` and `make package` produce a universal app containing both an
Apple Silicon (`arm64`) and an Intel (`x86_64`) slice, so one build runs on any
Mac that supports macOS 14. Add `ARCH=` to build for one architecture only:

| Command | What it builds |
| --- | --- |
| `make build` | Universal: Apple Silicon + Intel. |
| `make build ARCH=host` | Only this Mac's architecture. Faster, and all you need to run it here. |
| `make build ARCH=arm64` / `ARCH=x86_64` | One named architecture. |

`make test` only ever builds for this Mac, since the tests run here. Building
the Apple Silicon slice needs Metal's shader compiler, which ships with Xcode
and not with the Command Line Tools alone; if you only have the Command Line
Tools on an Intel Mac, use `make build ARCH=host`.

On Apple Silicon you can run the Intel slice of a universal build through
Rosetta 2 to check it:

```sh
./scripts/smoke-test.sh --arch x86_64
```

## Use

1. Launch DayScribe and wait for the menu bar microphone icon (the model loads once).
2. Press **Control + Option + N**. On first use, allow microphone access. Wait for the red recording icon before speaking.
3. Speak your note. Press the shortcut again to stop.
4. The icon shows transcription progress, then returns to the microphone when the note is saved.

The shortcut works while other applications have focus. It uses macOS hotkey registration, so Accessibility and Input Monitoring permissions are unnecessary. If another app has registered the shortcut, DayScribe reports the conflict; the menu's recording action remains available.

While the model loads, microphone permission is pending, or transcription is running, additional shortcut presses are ignored. Finish the current note before starting another. There is no recording queue, maximum recording timer, or push-to-talk mode. Quit is unavailable until recording/transcription finishes.

Menu actions:

- **Start / Stop Recording**
- **Open Today's Notes** — creates today's heading if needed and opens the file in your default Markdown editor
- **Open Notes Folder** — opens Finder
- **Show Last Error…** — available after a problem, kept only in memory
- **Launch at Login** — toggles automatic startup after you sign in
- **Quit DayScribe**

There is no normal window or Dock icon. Successful notes are silent. Errors request permission to display macOS notifications; if notifications are denied or unavailable, an alert displays the recovery information.

## Files

Notes go to `~/Documents/Dictation/YYYY-MM-DD.md`:

```markdown
# Notes - 2026-09-15

[10:17:42] Need to investigate why the MongoDB aggregation isn't using the index.

[11:36:08] Ask James whether Thursday's deployment can be moved to Friday.

```

Dates and 24-hour timestamps use your Mac's local time. **A note belongs to the date/time when recording started**, even if transcription finishes after midnight. The writer keeps paragraph breaks returned by the backend; Whisper usually produces a single paragraph and does not guarantee paragraph formatting from spoken pauses.

Existing content is preserved. Appends use an exclusive file lock, handle missing trailing newlines, and flush the write before audio deletion. Locks coordinate DayScribe writers; an external editor that saves over the whole file can still replace simultaneous changes. Keep the file closed in editors while dictating if those editors automatically save stale copies.

### Audio and recovery

- In-progress audio: `~/Library/Application Support/DayScribe/Pending/*.wav`.
- Recording format: 16 kHz, mono, 16-bit PCM WAV.
- After a successful transcription **and** successful Markdown write, audio is deleted.
- If recording, transcription, or writing fails, audio is moved to `~/Documents/Dictation/failed/`. A timestamp and UUID keep filenames unique.
- If that folder cannot be written, the original stays in `Pending/` and the error reports its path.
- On restart, leftover recordings are moved to `failed/` and reported. A recording interrupted before its WAV header was finalized may need audio-file repair.
- A crash after the Markdown write but before audio deletion can leave both the note and audio. Recovery does not auto-transcribe, avoiding duplicate entries. Check the notes before manually recovering audio.

The failure folder is the explicit exception to audio deletion. Review and remove recovered audio yourself. There is no retry/history interface. You can transcribe a recovered 16 kHz mono WAV without modifying notes:

```sh
dist/DayScribe.app/Contents/MacOS/DayScribe --transcribe /path/to/recovered.wav
```

`instance.lock` in Application Support prevents two copies running at once; it contains no notes or history. The app keeps no database, transcript cache, telemetry, analytics, or persistent application log.

## Local transcription and privacy

The app links [whisper.cpp v1.9.4](https://github.com/ggml-org/whisper.cpp/tree/v1.9.4) directly and keeps the `small.en` model resident. On Apple Silicon inference runs on the GPU through Metal, with Accelerate alongside it. Intel Macs have no GPU that whisper.cpp's Metal kernels can use, so they transcribe on the CPU with Accelerate and AVX2/FMA kernels; that works the same way and produces the same notes, but takes a few seconds per note rather than well under one. (The AVX2 baseline is Haswell and later, which covers every Intel Mac that can run macOS 14.) Beam-search decoding favors accuracy. The UI remains responsive because loading and inference run outside the main actor. First-run Metal initialization may take longer; actual latency depends on your Mac, note length, and audio quality. One-to-two-second transcription is an Apple Silicon target, not a guarantee.

All recording and inference run locally. The runtime has no networking code, external transcription process, Apple Speech service, API key, or model downloader. Whisper's curl support and server/examples are disabled at build time. Audio and transcript contents are not logged. The smoke test has been verified to pass under a macOS sandbox that denies all network access.

Your own filesystem settings still apply: if macOS syncs Documents with iCloud or another service, the notes and failed recordings in that directory can be synced by that service. Use a locally stored Documents directory if you require these files to stay only on this Mac.

Whisper can mishear speech or invent words in noisy/silent audio. DayScribe rejects near-silent and empty recordings and preserves their audio as failures, but does not promise perfect silence detection or transcription. Review important notes in your Markdown file.

## Development

```sh
make test    # file integrity, timestamps, rollover, concurrency, recovery
make smoke   # real model inference on whisper.cpp's bundled JFK WAV
```

The smoke test does not access the microphone, write daily notes, or make network requests. It prints model-loading and transcription timings. Use the `.app` bundle to run the utility; `swift run` lacks its resources and macOS permission metadata.

```text
Sources/DayScribe/
  AppDelegate.swift             App lifecycle, file actions, single-instance lock
  GlobalShortcutManager.swift   Carbon Control–Option–N registration
  MenuBarController.swift       Small status menu and state icons
  RecordingManager.swift        Recording → inference → write → cleanup
  AudioRecorder.swift           AVFoundation microphone capture
  NotificationManager.swift     Failure notifications and alert fallback
  LoginItemManager.swift        Launch at Login via ServiceManagement
Sources/DayScribeCore/
  TranscriptionService.swift    Swappable protocol + resident Whisper actor
  NotesWriter.swift             Append-only daily Markdown writer
  RecordingStore.swift          Pending and failed audio storage
Sources/WhisperBridge/          Small C ABI over whisper.cpp
Resources/                      App metadata and microphone entitlement
scripts/                        Reproducible local setup, build, verification
  bootstrap.sh                  Fetch whisper.cpp, build static libs per architecture, fetch model
  fetch-model.sh                Fetch and verify the model only
  build.sh                      Bootstrap + swift build + assemble and sign .app
  test.sh / smoke-test.sh       Unit tests / real inference on the sample WAV
  package.sh                    Zip the app for another Mac
  release.sh                    Developer ID sign, notarize, staple, and build the DMG
```

Continuous integration runs the unit tests on both Apple Silicon and Intel macOS runners for every pull request, builds the universal app on Apple Silicon, and builds and transcribes the sample natively on Intel; see `.github/workflows/ci.yml`.

### Manual acceptance check

1. Launch the app; verify a menu bar icon and no main window/Dock icon.
2. Focus another app, press Control–Option–N, grant microphone access, and dictate a sentence. Press again. Confirm the timestamped note and disappearance of its pending WAV.
3. Repeat twice; confirm only one date heading and that all entries remain.
4. Check the file/folder menu actions.
5. Record silence; confirm failure feedback and preserved WAV. Review "Show Last Error…" for the path.
6. Deny microphone access in System Settings → Privacy & Security → Microphone, then try recording; confirm actionable feedback.
7. Disable networking and repeat a normal note; recognition should work identically.

Settings, other models, and configurable shortcuts remain outside this version. See [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request.

## Copy a local build to another Mac

To give someone DayScribe, send them the [download link](#download). The steps below are for copying your own unnotarized build. The other Mac must run **macOS 14 or later**; Apple Silicon and Intel are both supported, and the packaged app contains a slice for each. No development tools, account, model download, or internet connection are needed to run it.

```sh
make package
```

1. Copy `dist/DayScribe-macOS-universal.zip` using AirDrop, a USB drive, or another file-transfer method. A `.sha256` sidecar is written next to it. (Building with `ARCH=` names the ZIP after that architecture instead.)
2. Double-click the ZIP on the other Mac to extract `DayScribe.app`.
3. Move the app into **Applications** (or your own `~/Applications` folder) before opening it.
4. Open DayScribe. This build is locally signed but not notarized. If macOS blocks it, attempt to open it once, then go to **System Settings → Privacy & Security → Open Anyway** for DayScribe. See [Apple's instructions](https://support.apple.com/en-gb/102445).
5. Press **Control + Option + N** and grant microphone access on that Mac.
6. Click the menu bar microphone and enable **Launch at Login**. A checkmark confirms it is enabled.

If the menu instead shows **Approval Needed**, select it to open macOS Login Items settings and allow DayScribe. This setting belongs to each Mac user account and must be enabled separately on the other Mac. It starts the app after login, including after a restart; it does not record automatically.

The model is inside the app bundle. Your notes, failed recordings, and microphone permissions are not included in the ZIP. Each Mac writes its own `~/Documents/Dictation/` files.

### Launch at Login administration

The menu reads the current macOS setting whenever it opens, including changes you make in System Settings. Uncheck **Launch at Login** to disable it. macOS stores the setting; DayScribe does not create a settings database or LaunchAgent file.

For local installation scripts, use the executable in the app's final installed location:

```sh
~/Applications/DayScribe.app/Contents/MacOS/DayScribe --enable-login
~/Applications/DayScribe.app/Contents/MacOS/DayScribe --login-status
~/Applications/DayScribe.app/Contents/MacOS/DayScribe --disable-login
```

When updating, quit DayScribe before replacing the installed app. Reopen it and check **Launch at Login**. Ad-hoc signing may also require granting microphone permission again. If you relocate the app, disable Launch at Login first, move it, then re-enable it from the new location.

## License

DayScribe is released under the [MIT License](LICENSE).

It statically links [whisper.cpp](https://github.com/ggml-org/whisper.cpp) (MIT) and downloads a GGML conversion of OpenAI's Whisper `small.en` model (MIT) at build time. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). Both licenses are also copied into the app bundle.
