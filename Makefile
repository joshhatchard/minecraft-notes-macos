APP_NAME   := BookAndQuill
BUILD_DIR  := build
APP_BUNDLE := $(BUILD_DIR)/$(APP_NAME).app
CONFIG     := release
# SwiftPM's intermediate files live outside the repo: when the repo sits in an
# iCloud-synced folder (Desktop/Documents), iCloud adds extended attributes that
# make codesign reject the test bundles. Override with `make SCRATCH=.build`.
SCRATCH    ?= $(HOME)/Library/Caches/$(APP_NAME)-build
SWIFT_FLAGS := --scratch-path "$(SCRATCH)"
BIN_DIR     = $(shell swift build $(SWIFT_FLAGS) -c $(CONFIG) --show-bin-path)
ASSETS_BUNDLE := $(APP_NAME)_BookAssets.bundle

.PHONY: build test run app snapshot lint format art clean

## Debug build of every module.
build:
	swift build $(SWIFT_FLAGS)

## Run the unit tests.
test:
	swift test $(SWIFT_FLAGS)

## Build and launch the app from the command line (no bundle).
run:
	swift run $(SWIFT_FLAGS) $(APP_NAME)

## Assemble a self-contained, ad-hoc signed build/BookAndQuill.app.
app:
	swift build $(SWIFT_FLAGS) -c $(CONFIG) --product $(APP_NAME)
	rm -rf "$(APP_BUNDLE)"
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS" "$(APP_BUNDLE)/Contents/Resources"
	cp "$(BIN_DIR)/$(APP_NAME)" "$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)"
	cp -R "$(BIN_DIR)/$(ASSETS_BUNDLE)" "$(APP_BUNDLE)/Contents/Resources/"
	cp Packaging/Info.plist "$(APP_BUNDLE)/Contents/Info.plist"
	iconutil -c icns Packaging/AppIcon.iconset -o "$(APP_BUNDLE)/Contents/Resources/AppIcon.icns"
	# iCloud Desktop sync can tag files with extended attributes that codesign rejects.
	xattr -cr "$(APP_BUNDLE)"
	codesign --force --sign - --timestamp=none "$(APP_BUNDLE)"
	codesign --verify --strict "$(APP_BUNDLE)"
	@echo "Built $(APP_BUNDLE)"

## Build the app, play every scenario in scenarios/ on throwaway libraries and
## write window snapshots to snapshots/ (see docs/DEBUGGING.md).
## `make snapshot ONLY=first-book` runs matching scenarios only.
snapshot: app
	scripts/snapshot.sh $(ONLY)

## Lint with swift-format (bundled with the Swift toolchain) if available.
lint:
	@if swift format --version >/dev/null 2>&1; then \
		swift format lint --recursive Sources Tests Package.swift; \
	else \
		echo "swift-format is not available; skipping lint."; \
	fi

## Reformat sources in place with swift-format.
format:
	swift format format --in-place --recursive Sources Tests Package.swift

## Regenerate our own placeholder pixel art (chest texture, app icon).
art:
	python3 scripts/generate_placeholder_art.py .

clean:
	rm -rf .build "$(SCRATCH)" "$(BUILD_DIR)"
