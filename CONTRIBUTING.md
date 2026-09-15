# Contributing to DayScribe

Thanks for your interest. DayScribe is deliberately small: one shortcut, one
model, one Markdown file per day. Contributions that keep it small are the
easiest to accept.

## Setting up

You need an Apple Silicon Mac, macOS 14 or later, and Xcode (or the Command
Line Tools). Then:

```sh
make test    # downloads and builds whisper.cpp, runs the unit tests
make build   # also downloads the model and produces dist/DayScribe.app
make smoke   # transcribes whisper.cpp's sample WAV with the built app
```

`make` targets are thin wrappers over the scripts in `scripts/`. Nothing is
installed outside the project directory. See the README for details.

## Before opening a pull request

- Run `make test` and `make smoke`; both must pass.
- Do the manual acceptance check in the README if you touched recording,
  the shortcut, the menu, notifications, or file writing.
- Keep the privacy promise: no networking code in the app, no telemetry, no
  logging of audio or transcript contents. Downloads happen only in
  `scripts/`, only from pinned URLs, and only with checksum verification.
- Do not commit the model, whisper.cpp sources, or build output. `.gitignore`
  already excludes them.
- Match the existing style: Swift 6 strict concurrency, `@MainActor` UI code,
  small files, comments only where the *why* is not obvious.

## Reporting bugs

Open a GitHub issue with your macOS version, Mac model, what you did, what
you expected, and the text from **Show Last Error…** in the menu if there is
one. Please do not attach recordings or notes that contain private content.

## Ideas that are out of scope for now

Configurable shortcuts, other Whisper models or languages, settings windows,
and cloud features. Issues proposing them are welcome for discussion, but a
pull request for them may not be merged without one first.
