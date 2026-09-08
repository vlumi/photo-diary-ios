# Photo Diary — iOS companion

Read-only iPhone companion for a self-hosted [Photo Diary](https://github.com/vlumi/photo-diary) instance. Browse your galleries by date, see every photo on a map, drop personal "revisit this later" pins.

The site is where you upload, edit, and administer. This app is what you carry in your pocket.

## Status

Pre-alpha. Repo scaffolded, no runtime yet. See [ROADMAP.md](ROADMAP.md) for v1 scope.

## Compatibility

- **iPhone only.** No iPad, no macOS, no Watch. Portrait-only.
- **Latest iOS.** No back-compat with older iOS versions — the app can freely use the newest APIs.
- **Requires a Photo Diary server** you have credentials for. See the [server repo](https://github.com/vlumi/photo-diary) for how to run one.

## TestFlight (internal)

The app is distributed to internal testers through TestFlight; nothing goes through App Store review. One-time setup: an App Store Connect API key (App Manager role) at `~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8`, and `Scripts/.asc-config` copied from `.asc-config.example` with the Key ID and Issuer ID. Then:

```shell
make distribute          # archive → export → upload
make distribute-build    # archive + export only, .ipa lands in dist/
make distribute-upload   # upload what's in dist/
```

Signing is automatic against the team in `project.yml`. The build number is the commit count on the current branch, so uploads from `main` are always increasing; the marketing version is `MARKETING_VERSION` in `project.yml`. Builds appear in TestFlight after a few minutes of processing and reach the internal group automatically.

## License

MIT. Same as the server.
