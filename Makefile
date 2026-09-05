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
	$(wildcard Sources/*/*.xcstrings)

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

.PHONY: ci
ci:  ## Run every check CI runs (lint + test + build), so a green run here is a green run there
	@$(MAKE) --no-print-directory lint
	@$(MAKE) --no-print-directory test
	@$(MAKE) --no-print-directory build

.PHONY: sync-schema
sync-schema:  ## Fetch server/openapi.json for TAG and regenerate the Swift client (TAG=v1.0.5)
	@Scripts/sync-schema.sh $(TAG)

.PHONY: clean
clean:  ## Remove the generated project + local build output
	@rm -rf PhotoDiary.xcodeproj .build-xcode Packages/PhotoDiaryCore/.build dist
	@echo "removed PhotoDiary.xcodeproj, .build-xcode, package .build, dist"
