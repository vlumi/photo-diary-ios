# Changelog

All notable changes to the Photo Diary companion app are documented here. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Grouped by **marketing version**, then by **build number** within it — the version stays steady while the build climbs with each TestFlight upload (see [RELEASING.md](RELEASING.md)). A build's section lists only what changed since the **previous build**, whether or not that build was the same version. The build heading is `### build N — <date>`; the version comes from the `## vX.Y.Z` above it.

Each version's top section, **Unreleased (next build)**, collects entries merged to `main` but not yet in a TestFlight build; cutting a release renames it to that build's heading and opens a fresh empty one. Keep that heading immediately followed by its list items (no prose between), so the release script can promote it. A user-facing PR writes its own bullet here.

**One bullet, one line — no hard wrapping.** Order the list by what a user notices, not by merge order, and fold entries that tell one story into one bullet.

## v0.1.0

### Unreleased (next build)

### build 2 — 2026-09-09

- **Todo pins by touch**: long-press the map to drop a pin where your finger is and write its note, long-press a pin and drag to move it, tap it for a banner with its note and a pencil to edit — the map-centre drop button is gone.
- **Pin list**: tapping a row only flies the map there; the pencil opens the editor.
- Dragging a todo pin no longer zooms the map underneath it.
- The previous-photo arrow on a pile's callout works; it used to open the photo instead.
- Callouts and the viewer show the photo's date and time.
- **Starred pins**: the list orders pins starred-first, then by last edit; a star on each row toggles it.
- The pin list can sort by distance from the map's centre and shows each pin's distance.
- Swiping in the enlarged viewer no longer skips a photo, and paging pauses while zoomed in.
- **Tap a pin to see the photo first**: a thumbnail pops up above it, and tapping that opens the full viewer; a pile of photos at one spot gets the same popup with arrows to browse what's there.
- **Swipe between photos** in the viewer — through the month from the calendar, or through a pile from the map — with chevrons and a position counter.
- **Show on map** from the photo viewer: opening a photo from the calendar can jump to where it was taken, framed at street level.
- **The map holds its place**: returning from a photo, or a background refresh, no longer re-fits the camera or blanks the map; a thin bar shows while pins refresh.
- **Pinch-to-zoom starts immediately** — pins and clusters no longer capture the first touch of a two-finger gesture.
- **Your location** is drawn on top of pins and clusters, follows you while the map is open, and the locate button zooms in close enough to see the street.

### build 1 — 2026-09-08

- **Pair with a Photo Diary instance** from the site's "Pair a device" code — scan the QR, open the link on the same device, or paste it — with an "Add this instance?" confirmation before anything is consumed; sessions persist in the Keychain across relaunches.
- **Calendar**: galleries → years → months → a day-sectioned photo grid, tapping into the full-screen viewer with pinch-zoom, pan, and double-tap zoom.
- **Map** of every geotagged photo across the instance's galleries, clustered for thousands of pins, opening centred on the most recent photo; tap a cluster to zoom in, or to list its photos when they share one spot.
- **Todo pins**: drop a note at the map centre, edit or delete it, list them all — stored on the device only.
- **Settings** lists paired instances, switches the active one, and forgets an instance (dropping its session).
- **Demo instance** with sample galleries works without a server, so the app is explorable before pairing.
