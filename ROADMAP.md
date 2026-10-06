# Roadmap

Living record of what the app is aiming for. Once something ships, its bullet moves to [CHANGELOG.md](CHANGELOG.md) and the roadmap slot is either retired or replaced.

## v1.0 — App Store launch

Shipped on 2026-10-07: [Photo Diary Companion on the App Store](https://apps.apple.com/app/id6808160193). [CHANGELOG.md](CHANGELOG.md) has what each build brought.

## v1.1 — post-launch polish

- **Universal Links** for the pairing "Open in app" button, closing the custom scheme's weakness that another app can claim `photodiary://` and catch the ticket. The app can only claim domains it lists, so the link has to point at a site of the app's own (e.g. `photodiary.misaki.fi/pair`, the ticket in the fragment), with the server's pairing dialog emitting it. The site side is live (photodiary.misaki.fi serves the association file for `/pair`); what's left is the app's Associated Domains entitlement and link handling, and the server's dialog.
- **Stats surface.** Reduced version — KPIs and category cards, skip charts initially. ~1-2 days.
- **Real demo photos.** The demo instance draws a gradient tile per photo; licensed photos bundled with the app would make the screenshots and the first impression better.

## v2 — direction, not planned

Speculative shape for what would come after the site's own 2.0 vision (thin server, uploads from client). None of this constrains v1.

- Companion becomes the primary capture path: shoot on the phone, EXIF + geocode locally, upload originals to the operator's chosen storage backend, notify the server.
- Widgets for "today N years ago" and the daily-diary shot-of-the-day.
- Watch complication for the diary streak.

## Deliberately not on the roadmap

See [ARCHITECTURE.md](ARCHITECTURE.md#deliberately-out-of-scope).
