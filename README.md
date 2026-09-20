# Photo Diary — iOS companion

Read-only iPhone companion for a self-hosted [Photo Diary](https://github.com/vlumi/photo-diary) instance. Browse your galleries by date, see every photo on a map, drop personal "revisit this later" pins.

The site is where you upload, edit, and administer. This app is what you carry in your pocket.

## Status

In internal TestFlight testing (v0.1.0); the App Store submission is the remaining v1.0 step. See [ROADMAP.md](ROADMAP.md) for what is left and [CHANGELOG.md](CHANGELOG.md) for what each build brought.

## What it does

- **Front page.** Every paired instance with its galleries. Open an instance to see all of its galleries together, or one gallery on its own. The app reopens where you left it.
- **Map.** Every geotagged photo as a pin, clustered by zoom; tap for a preview, tap again for the full photo. A location button follows you as you move. Long-press to drop a todo pin with a note, kept on the device only.
- **Calendar.** Gallery → year → month → day grid, or a whole year at once.
- **Photo viewer.** A sheet with pinch-zoom and paging; swipe down to close, or jump to the photo's place on the map.
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

[AGENTS.md](AGENTS.md) has the conventions and [ARCHITECTURE.md](ARCHITECTURE.md) how the app is put together.

## Releasing (TestFlight, internal)

Builds go to internal testers through TestFlight; nothing passes App Store review yet. `make release` from a clean `main` bumps the build (and optionally the version), stamps the changelog, opens and merges the release PR once CI is green, tags the merge commit, archives, and uploads. See [RELEASING.md](RELEASING.md) for the lane, recovery, and one-time setup.

## License

MIT. Same as the server.
