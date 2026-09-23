# photo-diary-ios — agent & contributor guide

Read-only iPhone companion for a self-hosted Photo Diary instance. This file is how to *work on* the repo — for humans and AI agents alike.

Fully independent of the [server repo](https://github.com/vlumi/photo-diary). The server exposes `/api/v1/*`; this app is a consumer, nothing more, and needs server 1.0.7 or later (device pairing).

## Where things are documented

One place per concern — don't duplicate, link:

| | |
|---|---|
| **What the system is** | [ARCHITECTURE.md](ARCHITECTURE.md) — the two-surface app (Map + Calendar), instances and scope, auth and pairing, localization, and a fenced *Planned* chapter |
| **How to ship it** | [RELEASING.md](RELEASING.md) — versioning, the `make release` lane, recovery |
| **How to work on it** | this file — conventions, toolchain, PR process |
| **What's next, and when** | [ROADMAP.md](ROADMAP.md) |
| **What shipped** | [CHANGELOG.md](CHANGELOG.md) |

When something ships, move it out of ARCHITECTURE.md's *Planned* chapter and into the prose above it.

## Conventions

- **Toolchain:** Xcode + Swift 6, **XcodeGen** (`.xcodeproj` generated, gitignored, never committed). Team ID committed in `project.yml` (not a secret; the release lane's headless signing needs it); certs/profiles fetched by `-allowProvisioningUpdates`.
- **Bundle id:** `fi.misaki.photodiary`.
- **Deployment target:** current-latest iOS only. No `#available` guards, no `@available` markers on public API, no legacy layout branches. Swift 6 strict concurrency clean from day one.
- **Device family:** iPhone. Portrait-only.
- **Spelling:** US English (en-US) everywhere — identifiers, comments, UI strings, docs, changelog, commit messages. `center`, `color`, `meter`, `recognized`.
- **Localization:** English and Japanese, via String Catalogs — never hardcoded literals. View strings (`Text("…")`, `String(localized:)` in `PhotoDiaryKit`) resolve against the **app** bundle, so their catalog is `Sources/Shared/Localizable.xcstrings`, not a package resource; its entries are `extractionState: manual` because Xcode can't see the package's sources from the app target. `PhotoDiaryCore` strings use `String(localized:, bundle: .module)` with the catalog in its own `Resources/`. Permission prompts live in `Sources/iOS/InfoPlist.xcstrings`. A `String` handed to `Text(_:)` or `navigationTitle(_:)` is shown verbatim, so wrap it in `String(localized:)`. Add a Japanese value with every new key, matching the site's terms (`react-app/src/lib/translations/ja.json` in photo-diary). Dates, numbers and distances follow the device language on their own (`CFBundleAllowMixedLocalizations`).
- **Comments minimal.** Comments earn their keep by capturing non-obvious constraints, not by narrating what the next line does.
- **Lint/format/CI:** SwiftLint + swift-format both `--strict`; CI runs lint + core tests (with coverage) + builds. Coverage-ignore the view layer; keep testable logic in `PhotoDiaryCore`.
- **PRs:** branch off `main`, one focused change; `Co-Authored-By: <model> <noreply@anthropic.com>` trailer; a user-facing PR writes its own CHANGELOG bullet; wait for CI before merging.

## Layout

```text
Packages/PhotoDiaryCore/            SPM package
  Sources/PhotoDiaryCore/           Logic, no UI: models, instances, API client, pairing,
                                    clustering, todo-pin store, its own String Catalog
  Sources/PhotoDiaryKit/            SwiftUI views + MapKit surface
  Sources/PhotoDiaryIcon/           Command-line renderer behind `make icon`
  Tests/PhotoDiaryCoreTests/        headless tests (XCTest and Swift Testing)
  Tests/PhotoDiaryKitTests/         the little of the view layer that is testable
Sources/Shared/                     Localizable.xcstrings (the view layer's strings, en + ja)
Sources/iOS/                        PhotoDiaryApp.swift, assets, entitlements, InfoPlist.xcstrings,
                                    privacy manifest
Scripts/                            generate, run-ios, release-*, distribute, sync-schema
project.yml                         XcodeGen source of truth (Info.plist values live here)
```

The Core / Kit split matches sibling projects (`../donpa`, `../skid`). Core is what tests import; Kit depends on Core and pulls SwiftUI + MapKit. Put logic worth testing in Core and keep views thin. SwiftLint caps a type body at 300 lines, a file at 450 and a function at 50, so a growing view gets split into extensions and helper types early.

`make ci` runs what CI runs (lint, tests, build). To check something on a simulator that tests can't reach — tap latency, a gesture, a screen in another language — add a throwaway `bundle.ui-testing` target to `project.yml` with a test under `Tests/UITests/`, read `Logger` output with `xcrun simctl spawn <udid> log stream`, and remove both before committing.

## Server API

The client is generated from the server's own OpenAPI document with Apple's [swift-openapi-generator](https://github.com/apple/swift-openapi-generator), and the generated code is committed:

- `Packages/PhotoDiaryCore/OpenAPI/openapi.json` is the server's document, pinned at a release tag. `make sync-schema TAG=v1.1.1` moves the pin and regenerates; the compiler then holds the app to that release. Do it as its own PR so the spec and code diff is reviewable.
- `OpenAPI/openapi-generator-config.yaml` lists the operations the app calls, by the server's operation names (`listGalleries`, `queryGalleryPhotos`, …). To call another, add its name and run `make generate-client`.
- `Sources/PhotoDiaryCore/Generated/` is the output. Never edit it; SwiftLint excludes it and each file opts out of swift-format. The generator itself lives in `Tools/OpenAPIGenerator`, outside the app's dependency graph, so the app's build, the release lane and CI never run it; only the small `OpenAPIRuntime` and `HTTPTypes` packages ship.
- `Remote/ServerModels+Domain.swift` maps the generated types to the app's own. It is the one place that decides what a missing value means.
- `PhotoDiaryAPI` stays hand-written and is the generated client's transport (`PhotoDiaryAPI+Transport.swift`): it owns the session cookies, the Keychain handoff, one refresh and retry on a 401, and not following redirects (pairing reads its cookies off the 302). `PhotoDiaryClient.call` turns the client's errors back into `InstanceError`.

Generated decoding is all-or-nothing per response: one element that doesn't match the document fails the whole list. That is acceptable because the server serializes every response through the same typed schema, but it means the document must be right. A field the server sometimes omits has to be optional there, not just in practice.

`ServerContractTests` covers what the compiler can't: the oldest supported server (`Fixtures/openapi-min.json`, moved with `make sync-schema TAG=v1.0.7 PIN=min`) must have every operation the app calls, take every parameter it sends, and promise enough for the generated types to decode; and the document must still describe the session the transport is written for.

## Deliberately out of scope

See [ARCHITECTURE.md](ARCHITECTURE.md#deliberately-out-of-scope) — no writes to the server, no offline mode beyond the on-disk response cache, no filters, no push notifications, no third-party analytics.
