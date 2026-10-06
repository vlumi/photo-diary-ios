# Photo Diary — iOS companion

Read-only iPhone companion for a self-hosted [Photo Diary](https://github.com/vlumi/photo-diary) instance. Browse your galleries by date, see every photo on a map, and pin the places you want to come back to.

Listed on the App Store as **Photo Diary Companion**; on the home screen it's *Photo Diary*.

The site is where you upload, edit, and administer. This app is what you carry in your pocket.

## Status

1.0.0 is on the [App Store](https://apps.apple.com/app/id6808160193); its page is [photodiary.misaki.fi/app](https://photodiary.misaki.fi/app/). See [ROADMAP.md](ROADMAP.md) for what comes next and [CHANGELOG.md](CHANGELOG.md) for what each build brought.

## What it does

- **Front page.** Every paired instance with its galleries. Open an instance to see all of its galleries together, or one gallery on its own. The app reopens where you left it.
- **Map.** Every geotagged photo as a pin, clustered by zoom; tap for a preview, tap again for the full photo. A location button follows you as you move. Touch and hold to drop a todo pin with a note and an optional camera snapshot, kept on the device only.
- **Calendar.** Gallery → year → month → day grid, or a whole year at once.
- **Photo viewer.** A sheet with pinch-zoom and paging; swipe down to close, or jump to the photo's place on the map or its day in the calendar.
- **Pairing, not passwords.** On the site, *Pair a device* shows a QR code, an "Open in app" link and a copyable link; the app never asks for a username or password. A built-in demo instance works without any server.
- **Offline-tolerant.** The last answer from each instance is kept on disk and shown first, then refreshed.
- **English and Japanese**, following the phone or chosen in Settings.

## Compatibility

- **iPhone only.** No iPad, no macOS, no Watch. Portrait-only.
- **Latest iOS.** No back-compat with older iOS versions — the app can freely use the newest APIs.
- **Requires a Photo Diary server**, version 1.0.7 or later (the first with device pairing), that you have an account on. See the [server repo](https://github.com/vlumi/photo-diary) for how to run one. The demo instance needs none.

## Working on it

Needs Xcode, [XcodeGen](https://github.com/yonaskolb/XcodeGen), SwiftLint and swift-format. The Xcode project is generated and never committed.

```sh
make run      # build and launch on an iPhone simulator
make ci       # everything CI runs: lint, tests, build
make help     # the rest
```

The App Store listing and screenshots come from the repo: `Scripts/asc/listing.json` and `Scripts/asc/shots.json`, synced with `make asc-listing` / `make shots` / `make asc-screenshots` (see [Scripts/asc/README.md](Scripts/asc/README.md)).

[AGENTS.md](AGENTS.md) has the conventions and [ARCHITECTURE.md](ARCHITECTURE.md) how the app is put together.

## Releasing

`make release` from a clean `main` cuts a build and uploads it to App Store Connect, for TestFlight and the App Store. [RELEASING.md](RELEASING.md) has the lane, the store submission, recovery, and one-time setup.

## License

MIT. Same as the server.
