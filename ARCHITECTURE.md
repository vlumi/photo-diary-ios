# Architecture

The app is a read-only iPhone companion for a self-hosted Photo Diary instance. Two surfaces meet the two use cases the operator has for the site:

- **Map** — where the walking-around case lives. Every photo as a pin, tap-to-view, plus local-only todo pins for places to revisit.
- **Calendar** — where date-shaped browsing lives (family / snapshot galleries). Gallery list → Year → Month → Day → Photo.

A tab bar switches between them. Both surfaces share one photo viewer, one instance registry, one auth layer.

## Packages

```text
Packages/PhotoDiaryCore/
├── Sources/PhotoDiaryCore/         Pure logic — no UI dependencies.
│   ├── API/                        openapi-typescript-style generated Swift
│   │                               client from server/openapi.json (pinned)
│   ├── Auth/                       Session model, refresh flow, Keychain
│   ├── Instances/                  Multi-instance registry, per-host config
│   ├── TodoPins/                   Local SwiftData store for map notes
│   └── Models/                     Domain types (Gallery, Photo, ...)
└── Sources/PhotoDiaryKit/          SwiftUI views + MapKit — depends on Core.
    ├── App/                        Root shell, tab bar, routing
    ├── Map/                        MapKit view, clustering, pin sheets
    ├── Calendar/                   Y/M/D/photo-grid views
    ├── Photo/                      Shared photo viewer (pinch-zoom sheet)
    ├── Onboarding/                 Instance pairing (QR + link + paste)
    └── Settings/                   Instance registry, sign-out
```

Core is what tests target. Kit depends on Core and pulls SwiftUI + MapKit.

## Instance registry

Multiple photo-diary instances per install. Each is a hostname + credentials pair; credentials live in the Keychain, keyed by host. The registry exposes an active-instance selector — most screens are scoped to whichever instance is active.

The active instance is per-app, not per-tab. Switching instances is a top-level action in Settings.

### The `Instance` protocol

All data access above `PhotoDiaryCore` goes through a single `Instance` protocol — `listGalleries()`, `queryPhotos(gallery, filter)`, `getPhoto(id)`, `listEvolution(...)`, etc. Two implementations:

- **`RemoteInstance`** — talks to a real photo-diary server. HTTPS, cookies, refresh loop, Keychain-backed session.
- **`DemoInstance`** — returns bundled fixture data. ~30 real-EXIF photos across 2 galleries embedded as SPM resources. No network, no auth, no server. Runs identically on-device and in unit tests.

Views only ever depend on the protocol, never on either concrete implementation. Swapping between them is a registry-level operation.

### Demo mode

The first-run onboarding offers **"Try demo mode"** alongside "Scan pairing QR" / "Paste pairing link". Choosing it adds a `DemoInstance` to the registry — indistinguishable from a real instance from the UI's perspective. Purposes:

- **Development without a server.** The entire UI can be built and tested against `DemoInstance` before the SSO pairing endpoint or `RemoteInstance` code exists.
- **App Store review.** Apple reviewers can't sign into the operator's servers. Demo mode IS the review credential — the app is fully explorable via it.
- **Screenshots** for the App Store listing come from demo mode. Consistent, no personal photos leaked.
- **Working offline.** Even after the app has been paired with real instances, the demo instance stays in the registry (unless the user removes it), so a subway-tunnel session still has something to browse.

Demo mode is read-only like the rest of the app; todo pins added while in demo mode live in the same SwiftData store as any other pins (they're local-only regardless).

## Auth

Same cookie flow the SPA uses:
- `pd_access` — short-lived JWT.
- `pd_refresh` — 90-day opaque token, rotated on every refresh.

Cookies live in `WKHTTPCookieStore`-adjacent Foundation cookie storage, scoped per instance. Refresh happens transparently on 401. On refresh-token expiry (90 days) the app prompts the user to re-pair.

## Onboarding — SSO pairing

Typing username + password + host on a phone keyboard is what the operator wants to avoid. If they're already logged in on their laptop, the phone piggybacks via a **one-use short-lived SSO ticket** — the same primitive the server already uses for the UserMenu cross-host switcher.

The server-side flow gets a new endpoint (`POST /api/v1/tokens/pairing`) that mints a ticket bound to the current user, TTL ~2 minutes. The SPA renders the ticket three ways so the same string covers every device topology:

1. **QR code** — for scanning from a laptop screen.
2. **"Open in app" button** — a `photodiary://sso?host=<host>&token=<ticket>` link that iOS routes to the app if installed. Same-device pairing.
3. **Pastable link** — copy the string, paste into the app's onboarding. Fallback for anything the first two miss.

The app catches all three and consumes the ticket via the existing `GET /api/v1/tokens/sso` endpoint, storing the refresh cookie in the Keychain.

Custom URL scheme (`photodiary://`) is enough for v1. Universal Links (real `https://` URLs backed by `.well-known/apple-app-site-association`) are v1.1 polish — make the "Open in app" button work from email / Messages / Notes and gracefully degrade to Safari when the app isn't installed.

The app shows an **"Add photos.example.com?"** confirmation before consuming — protects against hostile / mis-scanned QRs redirecting the pairing to a phishing host.

**Authenticated-only.** SSO pairing is the *only* way to add an instance. No manual host + username + password fallback in the app itself — if the user's session on the site expired, they log in there and re-pair. Keeps the app's threat model narrow (no credential input surface) and forces anonymous / guest access into the site where it belongs. Reinforces the "map is a tool for the operator" framing implicit in the auth-tier question below.

## Photo viewer

One component, used from both surfaces. Tap on a map pin OR a calendar photo cell opens a bottom sheet:
- Half-height by default — map / calendar still visible above.
- Swipe up → full-screen with pinch-zoom (backed by `UIScrollView` via `UIViewRepresentable`; native SwiftUI gestures work but the UIScrollView path is Photos.app's approach and rock-solid).
- Swipe down → dismiss back to the surface.
- Prev / next photo via horizontal swipe. Gated during zoom so pan doesn't accidentally navigate.
- Metadata panel available via an info button (title, EXIF, location, timestamp).

## Todo pins (map-only)

Local-only. Never leaves the device.

- **Schema:** `{id, lat, lng, note, createdAt, updatedAt}`. No categories, no due dates, no attached photos — deliberately minimal for v1.
- **Storage:** SwiftData. Survives reinstall via iCloud backup if the user has that on; otherwise a device-local store.
- **UI:**
  - Long-press map to drop a new pin at the target coordinate.
  - Tap a pin → sheet with the note (editable) + delete.
  - Distinct visual from photo pins — different color / icon.
  - List view in a separate tab (or a sheet from the map's toolbar), sorted by `updatedAt` descending. Tap a row → map centers on the pin and opens its sheet.

## Deliberately out of scope

- **Writes to the server.** No upload, no photo edit, no admin. The site is where you manage content.
- **Filters.** The site's filter widget is powerful but adds a whole UI surface. Come back to it if the browsing feel needs it.
- **Offline mode.** Assume connectivity. Later: cache the last-loaded photo set so opening in a dead zone shows something.
- **Push notifications.**
- **Third-party analytics or crash reporting.** iOS's built-in TestFlight crash logs are enough.
- **iPad, macOS, Watch.** Focus.

## Planned

Design questions still open. Move each into the prose above when settled.

### Should map access be user-scoped?

The site's map exposes precise coordinates for every photo the viewer can see. For anonymous / guest viewers of a public gallery this may or may not be desired — the operator has different intents per gallery (a public daily-BW project vs. a family gallery where GPS should stay off). Two shapes to consider:

- **Site-side gate**: `gallery.hide_map` already exists on the server; the map surface in the app respects it. Anonymous users of a hide-map gallery see photos on the calendar but no map. Simple.
- **Auth-tier gate**: the map (and todo pins) require a signed-in user, not `:guest`. Anonymous access still gets the calendar. Stricter; matches "map is a tool for the operator, not a public feature."

Both can coexist: `hide_map` per gallery for content sensitivity, plus a client-side "logged-in-only map tab" for the general case. Probably worth writing this into the app from day one — if the operator ever publishes a public daily project alongside a private family one, the toggle should already exist.

### Universal Links vs custom scheme

Custom scheme for v1, Universal Links for v1.1 (needs the `.well-known/apple-app-site-association` file served from every instance's host). Decide based on how often the "open pairing link from email" case comes up in practice.

### Cache strategy for offline

Not a v1 goal; not clear whether the right shape is "last query result stays in memory across background/foreground" (cheap) or "SwiftData persistence of every browsed photo" (heavier, opens dedup / eviction questions). Revisit when someone hits an unusable dead zone.
