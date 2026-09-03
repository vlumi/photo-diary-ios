# photo-diary-ios — agent & contributor guide

Read-only iPhone companion for a self-hosted Photo Diary instance. This file is how to *work on* the repo — for humans and AI agents alike.

Fully independent of the [server repo](https://github.com/vlumi/photo-diary). The server exposes `/api/v1/*`; this app is a consumer, nothing more. Schema drift is caught by a `Scripts/sync-schema.sh` that fetches `server/openapi.json` from a pinned server tag and regenerates the Swift client — the pinned tag is checked in.

## Where things are documented

One place per concern — don't duplicate, link:

| | |
|---|---|
| **What the system is** | [ARCHITECTURE.md](ARCHITECTURE.md) — the two-surface app (Map + Calendar), auth, API layer, and a fenced *Planned* chapter |
| **How to work on it** | this file — conventions, toolchain, PR process |
| **What's next, and when** | [ROADMAP.md](ROADMAP.md) |
| **What shipped** | [CHANGELOG.md](CHANGELOG.md) |

When something ships, move it out of ARCHITECTURE.md's *Planned* chapter and into the prose above it.

## Conventions

- **Toolchain:** Xcode + Swift 6, **XcodeGen** (`.xcodeproj` generated, gitignored, never committed). Team ID committed in `project.yml` (not a secret; the release lane's headless signing needs it); certs/profiles fetched by `-allowProvisioningUpdates`.
- **Bundle id:** `fi.misaki.photo-diary`.
- **Deployment target:** current-latest iOS only. No `#available` guards, no `@available` markers on public API, no legacy layout branches. Swift 6 strict concurrency clean from day one.
- **Device family:** iPhone. Portrait-only.
- **Localization:** English-only for v1, but String Catalog + `Text(_, bundle:)` / `String(localized:)` from day one — never hardcoded literals.
- **Comments minimal.** Comments earn their keep by capturing non-obvious constraints, not by narrating what the next line does.
- **Lint/format/CI:** SwiftLint + swift-format both `--strict`; CI runs lint + core tests (with coverage) + builds. Coverage-ignore the view layer; keep testable logic in `PhotoDiaryCore`.
- **PRs:** branch off `main`, one focused change; `Co-Authored-By: <model> <noreply@anthropic.com>` trailer; a user-facing PR writes its own CHANGELOG bullet; wait for CI before merging.

## Layout

```
Packages/PhotoDiaryCore/            SPM: pure API + models + persistence, no UI
  Sources/PhotoDiaryCore/           API client, auth, keychain, todo-pin store
  Sources/PhotoDiaryKit/            SwiftUI views + MapKit surface
  Tests/PhotoDiaryCoreTests/        headless tests
Sources/Shared/                     Assets.xcassets, Localizable.xcstrings
Sources/iOS/                        PhotoDiaryApp.swift, entitlements, Info.plist
Scripts/                            sync-schema, generate, release-*
project.yml                         XcodeGen source of truth
```

The Core / Kit split matches sibling projects (`../donpa`, `../skid`). Core is what tests import; Kit depends on Core and pulls SwiftUI + MapKit.

## Server schema

The Swift API client is generated from a pinned `server/openapi.json` — never from `main` on the server side. `Scripts/sync-schema.sh <server-tag>` fetches the spec from that tag, writes it to `Packages/PhotoDiaryCore/Sources/PhotoDiaryCore/Generated/`, regenerates the Swift models, and commits the pair. Bumping the server tag is a deliberate operation with a PR that reviews the diff.

## Deliberately out of scope

See [ARCHITECTURE.md](ARCHITECTURE.md#deliberately-out-of-scope) — no writes to the server, no offline mode beyond in-memory cache, no filters, no push notifications, no third-party analytics.
