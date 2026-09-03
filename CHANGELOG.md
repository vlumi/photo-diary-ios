# Changelog

Notable changes per release. Follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) shape; versions follow [SemVer](https://semver.org/).

## [Unreleased]

### Added

- Initial repo scaffold: XcodeGen `project.yml`, Package.swift split (`PhotoDiaryCore` + `PhotoDiaryKit`), Makefile, SwiftLint + swift-format configs, docs (README / AGENTS / ARCHITECTURE / ROADMAP / this file).
- Bundle id `fi.misaki.photodiary` (dropped the hyphen from the initial placeholder to match the sibling projects' shape).
- Locked design decisions in docs: authenticated-only onboarding (SSO pairing is the only way to add an instance), demo mode as v1 baseline (screenshots + App Store review + offline dev), `Instance` protocol with `DemoInstance` + `RemoteInstance` as parallel implementations.
