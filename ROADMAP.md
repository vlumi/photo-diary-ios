# Roadmap

Living record of what the app is aiming for. Once something ships, its bullet moves to [CHANGELOG.md](CHANGELOG.md) and the roadmap slot is either retired or replaced.

## v1.0 — App Store launch

Everything but the submission has shipped to TestFlight; [CHANGELOG.md](CHANGELOG.md) has the detail per build.

- **Shipped:** the toolchain and CI; the `Instance` protocol with the built-in demo instance; the instance registry; the shared photo viewer; the map with clustering, location following and todo pins; the calendar; the app shell; the real API client; SSO pairing (the server side landed in photo-diary 1.0.7, [vlumi/photo-diary#744](https://github.com/vlumi/photo-diary/issues/744)); and the polish pass (error, loading and empty states, accessibility, launch screen, app icon, privacy manifest).
- **Also shipped, brought forward from v1.1:** the front page that picks an instance or one gallery as the scope, full restoration of where the app was after a relaunch, the on-disk response cache with lazy refresh, a Japanese UI, and Settings with an app language and About.

What is left:

- **App Store submission.** Screenshots, the store description in English and Japanese, and the review. **Reviewers get two paths:** the demo instance, which is there out of the box and needs no server, and a test account on a live instance with the pairing steps in the review notes, so the real sign-in flow can be exercised. If review insists on signing in inside the app, a username and password form is the fallback; it is deliberately not built otherwise (see [ARCHITECTURE.md](ARCHITECTURE.md#onboarding--sso-pairing)).

## v1.1 — post-launch polish

- **Universal Links** for the pairing "Open in app" button. Needs `.well-known/apple-app-site-association` served from every instance's host and the App ID registered with Apple.
- **Stats surface.** Reduced version — KPIs and category cards, skip charts initially. ~1-2 days.
- **Real demo photos.** The demo instance draws a gradient tile per photo; licensed photos bundled with the app would make the screenshots and the first impression better.

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
