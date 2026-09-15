# Convenience entry points. Every target is a thin wrapper over scripts/*.sh.
.PHONY: all setup model build run test smoke package clean distclean

all: build

## Download whisper.cpp and build its static libraries (no model download).
setup:
	./scripts/bootstrap.sh --engine-only

## Download the Whisper small.en model (~488 MB) into models/.
model:
	./scripts/fetch-model.sh

## Download everything needed, then build dist/DayScribe.app.
build:
	./scripts/build.sh

## Build (if needed) and launch the app.
run: build
	open dist/DayScribe.app

## Run the unit tests. Does not need the model.
test:
	./scripts/test.sh

## Transcribe whisper.cpp's bundled sample with the built app.
smoke:
	./scripts/smoke-test.sh

## Build and zip the app for copying to another Apple Silicon Mac.
package:
	./scripts/package.sh

## Remove build products but keep downloads.
clean:
	rm -rf .build dist

## Remove build products and every downloaded artifact.
distclean: clean
	rm -rf .vendor .tools models
