# Roadmap

Living record of what the app is aiming for. Once something ships, its bullet moves to [CHANGELOG.md](CHANGELOG.md) and the roadmap slot is either retired or replaced.

## v1.0 — App Store launch

The full companion, both surfaces. Rough order of implementation:

1. **Scaffold + toolchain.** XcodeGen `project.yml`, Package.swift split (`PhotoDiaryCore` + `PhotoDiaryKit`), Makefile, CI (lint + test + build), String Catalog. Nothing that runs; the goal is a green CI on an empty app.
2. **API client (`PhotoDiaryCore`).** Auth flow + refresh loop, gallery / photo / stats endpoints, Keychain-backed cookie storage. Headlessly testable — no UI dependency.
3. **Instance registry.** Add / rename / remove hosts; per-host credentials. Settings screen.
4. **Onboarding — SSO pairing.** Three-transport pairing (QR / custom-scheme link / paste). Requires a corresponding `POST /api/v1/tokens/pairing` endpoint on the server side (see below).
5. **Shared photo viewer.** Bottom sheet, pinch-zoom, prev/next, metadata panel.
6. **Map surface.** MapKit view, photo pins with clustering, tap → photo viewer, persistent "you are here" via CoreLocation.
7. **Todo pins.** SwiftData model + list view + long-press-to-add + edit sheet.
8. **Calendar surface.** Gallery list → Year → Month → Day → Photo grid. Portrait-stacked, not multi-pane.
9. **Tab bar + app shell.** Map | Calendar tabs. Settings from a top-level button.
10. **Polish.** Error states, loading placeholders, empty states, accessibility pass, launch image, app icon.
11. **App Store submission.** Icons, screenshots, description, privacy manifest, TestFlight → App Store review.

Estimated at ~11-13 dev days total. Individual items get their own PRs with a CHANGELOG bullet when landed.

### Server-side dependency

**Pairing endpoint** (`POST /api/v1/tokens/pairing`) is the only server change needed for v1. It reuses the existing SSO ticket infrastructure — mints a one-use ticket bound to the current user, TTL ~2 minutes, consumed via the existing `GET /api/v1/tokens/sso`. Filed in the server repo before app development gets far enough to need it.

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
