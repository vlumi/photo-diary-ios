# Photo Diary — iOS companion

Read-only iPhone companion for a self-hosted [Photo Diary](https://github.com/vlumi/photo-diary) instance. Browse your galleries by date, see every photo on a map, drop personal "revisit this later" pins.

The site is where you upload, edit, and administer. This app is what you carry in your pocket.

## Status

Pre-alpha. Repo scaffolded, no runtime yet. See [ROADMAP.md](ROADMAP.md) for v1 scope.

## Compatibility

- **iPhone only.** No iPad, no macOS, no Watch. Portrait-only.
- **Latest iOS.** No back-compat with older iOS versions — the app can freely use the newest APIs.
- **Requires a Photo Diary server** you have credentials for. See the [server repo](https://github.com/vlumi/photo-diary) for how to run one.

## Releasing (TestFlight, internal)

Builds go to internal testers through TestFlight; nothing passes App Store review. `make release` from a clean `main` bumps the build (and optionally the version), stamps the changelog, opens and merges the release PR once CI is green, tags the merge commit, archives, and uploads. See [RELEASING.md](RELEASING.md) for the lane, recovery, and one-time setup.

## License

MIT. Same as the server.
