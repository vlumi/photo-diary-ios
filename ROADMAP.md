# Roadmap

Living record of what the app is aiming for. Once something ships, its bullet moves to [CHANGELOG.md](CHANGELOG.md) and the roadmap slot is either retired or replaced.

## v1.0 — App Store launch

The full companion, both surfaces. Rough order of implementation:

1. **Scaffold + toolchain.** XcodeGen `project.yml`, Package.swift split (`PhotoDiaryCore` + `PhotoDiaryKit`), Makefile, CI (lint + test + build), String Catalog. Nothing that runs; the goal is a green CI on an empty app.
2. **API client interface + demo instance (`PhotoDiaryCore`).** Define the `Instance` protocol (list galleries, query photos, get one photo, list evolution, etc.). Ship a `DemoInstance` that returns bundled fixture data (2 galleries, ~30 photos with real EXIF + GPS + timestamps, resource-embedded). Headlessly testable — no UI, no network.
3. **Instance registry + demo entry point.** Add / rename / remove hosts; per-host credentials. First-run onboarding offers a "Try demo mode" button that adds the `DemoInstance` to the registry. Every downstream view develops against demo mode until the real API client lands.
4. **Shared photo viewer.** Bottom sheet, pinch-zoom, prev/next, metadata panel. Built against `DemoInstance` — real network not needed yet.
5. **Map surface.** MapKit view, photo pins with clustering, tap → photo viewer, persistent "you are here" via CoreLocation. Demo-instance-driven.
6. **Todo pins.** SwiftData model + list view + long-press-to-add + edit sheet. Local-only either way; demo mode doesn't affect this surface.
7. **Calendar surface.** Gallery list → Year → Month → Day → Photo grid. Portrait-stacked, not multi-pane. Demo-instance-driven.
8. **Tab bar + app shell.** Map | Calendar tabs. Settings from a top-level button.
9. **Real API client (`RemoteInstance`).** Auth flow + refresh loop, gallery / photo / stats endpoints, Keychain-backed cookie storage. Same protocol as `DemoInstance` — a drop-in replacement for the demo path.
10. **Onboarding — SSO pairing.** Three-transport pairing (QR / custom-scheme link / paste). Requires the corresponding `POST /api/v1/tokens/pairing` endpoint on the server side (see below).
11. **Polish.** Error states, loading placeholders, empty states, accessibility pass, launch image, app icon.
12. **App Store submission.** Icons, screenshots, description, privacy manifest, TestFlight → App Store review. **App Store review credentials = demo mode** — reviewers get the demo instance out of the box, no server access needed.

Estimated at ~12-14 dev days total. Individual items get their own PRs with a CHANGELOG bullet when landed.

The demo-first order matters: steps 2-8 develop the whole UI against `DemoInstance` fixture data, so the app is functional (screenshots, App Store review, offline work sessions) before the real server connection is wired. Steps 9-10 are the "make it real" pass and can happen in parallel with the server-side pairing endpoint PR without blocking each other.

### Server-side dependency

**Pairing endpoint** (`POST /api/v1/tokens/pairing`) is the only server change needed for v1. It reuses the existing SSO ticket infrastructure — mints a one-use ticket bound to the current user, TTL ~2 minutes, consumed via the existing `GET /api/v1/tokens/sso`. Tracked in the server repo as [vlumi/photo-diary#744](https://github.com/vlumi/photo-diary/issues/744). App development can proceed against demo mode without this endpoint existing; step 10 is where the two tracks meet.

## v1.1 — post-launch polish

- **Universal Links** for the pairing "Open in app" button. Needs `.well-known/apple-app-site-association` served from every instance's host and the App ID registered with Apple.
- **Offline cache.** In-memory carry-over of the last-loaded photo set so opening the app in a dead zone shows something rather than a blank state.
- **Stats surface.** Reduced version — KPIs and category cards, skip charts initially. ~1-2 days.

## v2 — direction, not planned

Speculative shape for what would come after the site's own 2.0 vision (thin server, uploads from client). None of this constrains v1.

- Companion becomes the primary capture path: shoot on the phone, EXIF + geocode locally, upload originals to the operator's chosen storage backend, notify the server.
- Widgets for "today N years ago" and the daily-diary shot-of-the-day.
- Watch complication for the diary streak.

## Deliberately not on the roadmap

- Filters (redo the site's filter widget in SwiftUI — huge surface, low pay-off).
- iPad / macOS / Watch app.
- Push notifications.
- Third-party analytics.
- Cloud sync of todo pins (they're deliberately local-only).
