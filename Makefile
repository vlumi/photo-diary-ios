# photo-diary-ios — command-line build/test/lint, so you never have to open Xcode.
# Run `make` (or `make help`) to list targets.

.DEFAULT_GOAL := help

.PHONY: help
help:  ## List the available commands
	@echo "photo-diary-ios — available make targets:"
	@awk 'BEGIN {FS = ":.*## "} \
		/^[a-zA-Z0-9_-]+:.*## / {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Inputs xcodegen reads — regenerate the project when any of these change.
# Info.plist is not in this list: xcodegen synthesises it under
# .build-xcode/generated/ from project.yml properties, so project.yml
# alone captures every plist-affecting change.
PROJECT_INPUTS := project.yml \
	$(wildcard Sources/*/*.entitlements) \
	$(wildcard Sources/*/*.xcstrings) \
	$(wildcard Sources/*/*.xcprivacy)

PhotoDiary.xcodeproj: $(PROJECT_INPUTS)
	@Scripts/generate.sh

.PHONY: generate
generate: PhotoDiary.xcodeproj  ## Regenerate PhotoDiary.xcodeproj from project.yml (if stale)

.PHONY: run
run: PhotoDiary.xcodeproj  ## Build + launch on an iPhone simulator (DEVICE="17 Pro" / "SE")
	@Scripts/run-ios.sh "$(DEVICE)"

.PHONY: build
build: PhotoDiary.xcodeproj  ## Build the app (simulator, unsigned)
	@xcodebuild build -project PhotoDiary.xcodeproj -scheme PhotoDiary-iOS \
		-destination 'generic/platform=iOS Simulator' -derivedDataPath .build-xcode \
		CODE_SIGNING_ALLOWED=NO -quiet

.PHONY: test
test:  ## Run the package logic tests
	@swift test --package-path Packages/PhotoDiaryCore

.PHONY: lint
lint:  ## SwiftLint + swift-format, both strict (as CI runs them)
	@swiftlint lint --strict
	@swift format lint --strict --recursive --configuration .swift-format \
		Packages/PhotoDiaryCore/Sources Packages/PhotoDiaryCore/Tests Sources

.PHONY: format
format:  ## Rewrite sources with swift-format
	@swift format --in-place --recursive --configuration .swift-format \
		Packages/PhotoDiaryCore/Sources Packages/PhotoDiaryCore/Tests Sources

.PHONY: icon
icon:  ## Regenerate the app icon PNG from AppIconScene (opaque, as App Store Connect requires)
	@swift run --package-path Packages/PhotoDiaryCore photodiary-icon \
		"$(CURDIR)/Sources/iOS/Assets.xcassets/AppIcon.appiconset/AppIcon.png"

.PHONY: ci
ci:  ## Run every check CI runs (lint + test + build), so a green run here is a green run there
	@$(MAKE) --no-print-directory lint
	@$(MAKE) --no-print-directory test
	@$(MAKE) --no-print-directory build

# Release lane — see RELEASING.md. UPLOAD=0 stops after export.
UPLOAD ?= 1
DIST_FLAGS := $(if $(filter 0,$(UPLOAD)),--no-upload,)

.PHONY: release
release: release-distribute  ## Cut a release: bump → PR → CI → tag → archive → upload (UPLOAD=0 to skip ASC)
	@echo "✓ release complete."

.PHONY: release-build
release-build:  ## Like `release` but stop after export (no upload)
	@$(MAKE) release UPLOAD=0

.PHONY: release-preflight
release-preflight:  ## Release step 1: verify a clean, up-to-date base (main or release/X.Y.x)
	@Scripts/release-preflight.sh

.PHONY: release-publish
release-publish: release-preflight  ## Release step 2: bump, open the PR, wait for CI, merge
	@Scripts/release-publish.sh

.PHONY: release-tag
release-tag: release-publish  ## Release step 3: tag the merge commit + publish the GitHub release
	@Scripts/release-tag.sh

.PHONY: release-distribute
release-distribute: release-tag  ## Release step 4: archive/export (+ upload unless UPLOAD=0)
	@Scripts/release-distribute.sh $(DIST_FLAGS)

.PHONY: release-distribute-retry
release-distribute-retry:  ## Re-distribute an already-tagged release (no PR/tag steps)
	@Scripts/release-distribute.sh $(DIST_FLAGS) --require-tag

.PHONY: release-upload
release-upload:  ## Upload the already-built dist/ package (no rebuild)
	@Scripts/release-distribute.sh --upload-only

.PHONY: sync-schema
sync-schema:  ## Fetch server/openapi.json for TAG and regenerate the Swift client (TAG=v1.0.5)
	@Scripts/sync-schema.sh $(TAG)

.PHONY: clean
clean:  ## Remove the generated project + local build output
	@rm -rf PhotoDiary.xcodeproj .build-xcode Packages/PhotoDiaryCore/.build dist
	@echo "removed PhotoDiary.xcodeproj, .build-xcode, package .build, dist"
