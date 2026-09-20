# Architecture

The app is a read-only iPhone companion for a self-hosted Photo Diary instance. Two surfaces meet the two use cases the operator has for the site:

- **Map** — where the walking-around case lives. Every photo as a pin, tap-to-view, plus local-only todo pins for places to revisit.
- **Calendar** — where date-shaped browsing lives (family / snapshot galleries). Gallery list → Year → Month → Day → Photo.

The front page lists every paired instance with its galleries; tapping one opens the two surfaces on that **scope** (instance, or instance + gallery), and a tab bar switches between them. Both surfaces share one photo viewer, one instance registry, one auth layer.

## Packages

```text
Packages/PhotoDiaryCore/
├── Sources/PhotoDiaryCore/         Logic — no UI dependencies. What tests target.
│   ├── Models/                     Domain types (Gallery, Photo, PhotoTimestamp, …)
│   ├── Instance/                   The Instance protocol, the demo instance, the
│   │                               registry, the open scope, restoration state
│   ├── Remote/                     RemoteInstance: API client, wire models, session
│   │                               cookies, on-disk response cache
│   ├── Pairing/                    Pairing tickets and service, Keychain session
│   │                               store, registry persistence
│   ├── Image/                      Image loading: Nuke for http(s), drawn tiles for
│   │                               the demo, routed by URL scheme
│   ├── Map/                        Pins from photos, clustering, location following
│   ├── Calendar/                   Slicing photos by year, month and day
│   ├── TodoPins/                   Local SwiftData store for map notes
│   ├── Settings/                   The app language override
│   └── Resources/                  String Catalog for Core's error messages
├── Sources/PhotoDiaryKit/          SwiftUI views + MapKit — depends on Core.
│   ├── AppShell.swift              Root: front page, or the tab bar for the open scope
│   ├── Scope/                      Front page: instances and their galleries
│   ├── Map/                        Map view, annotations, callouts, todo-pin sheets
│   ├── Calendar/                   Gallery, year and month lists; the photo grid
│   ├── PhotoPagerSheet.swift, …    The shared photo viewer
│   ├── Onboarding/                 Pairing: QR scanner, link, paste
│   └── Settings/                   Settings and About
└── Sources/PhotoDiaryIcon/         Command-line tool that renders the app icon
Sources/Shared/                     The view layer's String Catalog (en + ja)
Sources/iOS/                        App entry point, assets, Info.plist strings
```

Core is what tests target. Kit depends on Core and pulls SwiftUI + MapKit; logic worth testing (clustering, follow rules, calendar slicing, the language store) is kept in Core for that reason.

## Instance registry

Multiple photo-diary instances per install. A remote instance is identified by its origin (scheme, host, port); its session lives in the Keychain under that id. The registry holds the open **scope** — an instance, optionally narrowed to one gallery — and persists it, so a relaunch lands where the app was. Every screen reads it; the front page sets it, and a button on the map and calendar clears it to return there. If the server stops accepting the session or withdraws access to what the scope shows, the registry drops the scope and the front page explains why, with a way to open the site and pair again.

Beyond the scope, a `RestorationStore` remembers per scope which tab was open, the calendar's navigation path and the map's camera, so the app comes back as it was after iOS recycles it.

Each remote instance keeps the last JSON answer per endpoint on disk (`ResponseCache`, under Caches); screens render that first and refresh behind it, so a relaunch or a dead zone shows what was there last.

### The `Instance` protocol

All data access above `PhotoDiaryCore` goes through a single `Instance` protocol: `listGalleries()`, `listPhotos(inGallery:)`, `getPhoto(id:inGallery:)`, and the cached variants of the first two that answer from disk without touching the network. Two implementations:

- **`RemoteInstance`** — talks to a real photo-diary server through `PhotoDiaryAPI`, a small hand-written client over the endpoints the app reads (`APIRoute`), with wire models (`WireModels.swift`) that decode only the fields it uses. A contract test checks both against the server's OpenAPI document, pinned at a release tag. Photo queries carry the app's language, so the server picks localized titles.
- **`DemoInstance`** — fixture data defined in code: two galleries and thirty photos with timestamps, places and coordinates. No network, no auth, no server. Runs identically on-device and in unit tests. Its photos are gradient tiles drawn per URL by `DemoImageLoader`, not bundled images.

Views only ever depend on the protocol, never on either concrete implementation.

### Demo mode

The demo instance is seeded into the registry on first launch, so the app has something to show before any pairing. It can be forgotten from the front page like any other instance. Purposes:

- **Development without a server.** The entire UI was built and is tested against `DemoInstance`.
- **App Store review and screenshots.** Reviewers can explore the app without credentials, and screenshots leak no personal photos. (Review also gets a test account for the pairing flow; see [ROADMAP.md](ROADMAP.md).)
- **Working offline.** A subway-tunnel session still has something to browse.

Demo mode is read-only like the rest of the app; todo pins added while in demo mode live in the same SwiftData store as any other pins (they're local-only regardless).

## Auth

Same cookie flow the SPA uses:

- `pd_access` — short-lived JWT.
- `pd_refresh` — 90-day opaque token, rotated on every refresh.

The cookies are managed by hand (`SessionCookies`) rather than through the system cookie jar, so each instance keeps its own pair, nothing leaks across hosts, and the values persist to the Keychain (`KeychainSessionStore`) as plain strings. A 401 triggers one `POST /api/v1/tokens/refresh` and a single retry. When the refresh token itself is refused, the request fails as *session expired* and the app offers to open the site and pair again. Photo bytes are public static files, so image loading carries no cookies.

## Onboarding — SSO pairing

Typing username + password + host on a phone keyboard is what the operator wants to avoid. If they're already logged in on their laptop, the phone piggybacks via a **one-use short-lived SSO ticket** — the same primitive the server uses for its cross-host switcher.

On the site, *Pair a device* in the user menu calls `POST /api/v1/tokens/pairing` (photo-diary 1.0.7 and later), which mints a ticket bound to the current user with a two-minute life. The site renders the ticket three ways so the same string covers every device topology:

1. **QR code** — for scanning from a laptop screen.
2. **"Open in app" button** — a `photodiary://sso?host=<host>&token=<ticket>` link that iOS routes to the app. Same-device pairing.
3. **Pastable link** — copy the string, paste into the app. Fallback for anything the first two miss.

The app catches all three and consumes the ticket via `GET /api/v1/tokens/sso`, storing the resulting cookies in the Keychain. A link with `scheme=http` pairs with a plain-http instance on the local network (a development server); App Transport Security allows that for local hosts only, and the confirmation warns about it.

The app shows an **"Add photos.example.com?"** confirmation before consuming — protects against hostile / mis-scanned QRs redirecting the pairing to a phishing host.

**Authenticated-only.** SSO pairing is the *only* way to add an instance. No manual host + username + password fallback in the app itself — if the user's session on the site expired, they log in there and re-pair. Keeps the app's threat model narrow (no credential input surface) and forces anonymous / guest access into the site where it belongs. The one thing that would change this is App Store review demanding an in-app sign-in.

## Map

Pins are derived, not stored. `PhotoMapping` turns photos with coordinates into pins, and `MapClustering` buckets them into square cells whose size is a power of two in degrees, anchored to absolute coordinates so panning never reshuffles clusters — only zooming does. A tap on a cluster zooms into it, or lists its photos when zooming would not separate them (a pile at one spot).

Pins are built for up to two screens past the viewport, within a budget of 200 annotations: every rebuild of the annotation set stalls SwiftUI's `Map` for a time proportional to the total count, however few pins changed, so the area shrinks where the map is crowded and rebuilds happen as rarely as possible — mid-pan only when half a screen of built area is left, and again when the camera comes to rest.

SwiftUI's `Map` commits an annotation selection only after its double-tap wait of about 0.6 s, so pins carry their own tap gestures and the map's late echo of the same tap is dropped. The location button is a mode (`FollowState`): it re-centers on the user at most every ten seconds until the user moves the map, keeps the current zoom when that already shows the surroundings, and zooms in to street level only from far out.

## Photo viewer

One component, used from both surfaces. A tap on a map callout or a calendar cell opens a sheet over the surface:

- The cached thumbnail shows at once and the full image replaces it, so the tap responds before anything loads.
- Pinch, pan and double-tap zoom are SwiftUI gestures (`PhotoViewer`). Horizontal paging is a scroll view underneath; it is switched off while zoomed so a pan doesn't turn the page.
- Swipe down closes the sheet. Because a SwiftUI drag gesture inside a horizontal scroll view never receives vertical drags, a UIKit pan recognizer attached to the enclosing scroll view does this (`PullDownRecognizer`); while zoomed, the same pan moves the photo instead.
- The caption shows the position in the set and the date in the photo's own local time. *Show on map* switches to the map centered on the photo. There is no EXIF panel.

## Todo pins (map-only)

Local-only. Never leaves the device.

- **Schema:** `{id, latitude, longitude, note, starredAt, createdAt, updatedAt}`. No categories, no due dates, no attached photos — deliberately minimal.
- **Storage:** SwiftData. Survives reinstall via iCloud backup if the user has that on; otherwise a device-local store.
- **UI:**
  - Long-press the map to drop a new pin there; press and hold an existing pin to move it.
  - Tap a pin for a callout with the note and an edit button; the editor also deletes.
  - Distinct visual from photo pins.
  - A list sheet from the map, sorted by most recent or by nearest to the map's center, with starred pins first. Tap a row → the map centers on the pin.

## Localization

English and Japanese. The view layer's strings live in the **app** target's String Catalog (`Sources/Shared/Localizable.xcstrings`), because SwiftUI resolves `Text("…")` against the main bundle even when the view is compiled in a package; Core's error messages use their own catalog with `bundle: .module`. Dates, numbers and distances are formatted by Foundation in the phone's language whatever the UI language (`CFBundleAllowMixedLocalizations`), so a Finnish phone gets Finnish dates around English words.

Settings can force a language for the app alone. It writes `AppleLanguages` into the app's own defaults — the key iOS's per-app language setting uses — and applies from the next launch. Doing it at process level rather than through SwiftUI's environment is what makes MapKit's labels follow.

## Deliberately out of scope

- **Writes to the server.** No upload, no photo edit, no admin. The site is where you manage content.
- **Filters.** The site's filter widget is powerful but adds a whole UI surface. Come back to it if the browsing feel needs it.
- **Offline mode beyond the response cache.** The last answers per endpoint are kept (see Instance registry); there is no download-for-later, no image cache promise beyond Nuke's, and nothing queued for a reconnect.
- **EXIF and the site's statistics.** The viewer shows the photo and its date.
- **Push notifications.**
- **Third-party analytics or crash reporting.** iOS's built-in TestFlight crash logs are enough.
- **iPad, macOS, Watch.** Focus.

## Planned

Design questions still open. Move each into the prose above when settled. (Settled: the offline cache is the per-endpoint `ResponseCache` described under Instance registry — raw responses, not a photo store.)

### Should map access be user-scoped?

The site's map exposes precise coordinates for every photo the viewer can see. For anonymous / guest viewers of a public gallery this may or may not be desired — the operator has different intents per gallery (a public daily-BW project vs. a family gallery where GPS should stay off). Two shapes to consider:

- **Site-side gate**: `gallery.hide_map` already exists on the server; the map surface in the app respects it. Anonymous users of a hide-map gallery see photos on the calendar but no map. Simple.
- **Auth-tier gate**: the map (and todo pins) require a signed-in user, not `:guest`. Anonymous access still gets the calendar. Stricter; matches "map is a tool for the operator, not a public feature."

Both can coexist: `hide_map` per gallery for content sensitivity, plus a client-side "logged-in-only map tab" for the general case. Neither exists yet: the app does not read `hide_map`, and since every instance is paired by a signed-in user, the map only ever shows what that user may see on the site.

### Universal Links vs custom scheme

Custom scheme for v1, Universal Links for v1.1 (needs the `.well-known/apple-app-site-association` file served from every instance's host). Decide based on how often the "open pairing link from email" case comes up in practice.

