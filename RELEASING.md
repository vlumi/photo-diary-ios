# Releasing

How the Photo Diary companion app versions, builds, and ships to TestFlight. Mechanical steps only. The lane mirrors the sibling apps' — this app is iOS-only, so there is no platform argument and tags carry no platform prefix.

## Branching

Trunk-based: `main` is the single trunk. Every change is a short-lived branch → PR → merge to `main`. Releases are **tags**, not long-lived branches. No `develop` branch.

**Version-line release branches are cut on demand, not routinely** — only to patch an already-shipped version after trunk has moved on. Branch `release/<minor>.x` from that version's last release tag (`git switch -c release/0.1.x v0.1.0-3`), land fixes on it via PRs into it, cut the patch build with the normal lane from the branch (the build number continues past every existing tag, so trains never collide), cherry-pick every fix back to `main`, and delete the branch once the patched version ships. Distinct from the transient `release/vX.Y.Z-N` branch the lane creates to carry a bump PR.

## Versioning

Two numbers, both in [project.yml](project.yml) (the source of truth — the `.xcodeproj` is generated, never hand-edited):

| Setting | Info.plist key | Meaning | Rule |
| --- | --- | --- | --- |
| `MARKETING_VERSION` | `CFBundleShortVersionString` | User-facing version, e.g. `0.1.0` | SemVer. Bump on a meaningful milestone. |
| `CURRENT_PROJECT_VERSION` | `CFBundleVersion` | Build number, e.g. `3` | Strictly increasing per upload. The lane sets it to one past the highest existing tag, so it never goes backwards even across a version bump. |

- **New build of the same version** (`0.1.0 (3)` → `0.1.0 (4)`): bump only the build. Internal testers get it after processing; no review.
- **New version** (`0.1.0` → `0.2.0`): bump `MARKETING_VERSION` when a roadmap milestone lands ([ROADMAP.md](ROADMAP.md)), never for routine iteration. Internal TestFlight needs no Beta App Review either way; the version string is what the changelog, tags and GitHub releases are filed under.

## Cutting a release

One command from a clean, up-to-date release base — `main`, or a version-line `release/<minor>.x` branch:

```sh
make release              # bump → PR → CI → tag → archive → upload
make release UPLOAD=0     # everything through export, no ASC upload
make release-build        # alias for UPLOAD=0
```

`make release` runs a four-step chain (each step its own [`Scripts/release-*.sh`](Scripts/); the Makefile wires the order). The pure steps re-derive their inputs from git + `project.yml`, so the only state passed between them is the merged commit on the base:

1. **preflight** — refuse unless on a clean release base matching its origin, with `gh` / `xcodegen` available and an opaque app icon (App Store Connect silently rejects a transparent one).
2. **publish** — the interactive step. Prompts to bump `MARKETING_VERSION` (blank = keep, `p` = patch, `m` = minor, or `X.Y.Z`); always bumps the build to one past the highest tag. Stamps the changelog's *Unreleased (next build)* into `### build N — <date>` — opening a `## vX.Y.Z` section when the version changed. Commits on `release/vX.Y.Z-N`, opens a PR, and **blocks until CI passes and it merges**. `main` has no branch protection yet, so auto-merge can't be armed; the script merges directly once CI is green — the green-before-merge guarantee holds either way. Red CI stops here with the PR left open.
3. **tag** — tags the merge commit `vX.Y.Z-N` and publishes a GitHub release with a version / build / commit table and the commits since the previous tag.
4. **distribute** — regenerates the project, archives, exports, and (unless `UPLOAD=0`) uploads via [Scripts/distribute.sh](Scripts/distribute.sh).

### Tags

Every tag is exactly `vMAJOR.MINOR.PATCH-BUILD` — plain SemVer plus the **build number**, never a `-beta.N` / `-rc.N` label: the lane orders tags with `--sort=-v:refname` and parses `(version, build)` to find the previous release for the notes, and a pre-release suffix would mis-sort. The git tags are the source of truth; GitHub releases are a presentation layer. Never delete an immutable GitHub release — GitHub reserves the tag name permanently; *edit* to revise notes.

## Recovering from a failed release

The steps are idempotent against the real artifacts (tags, merge state). Re-enter the chain at the right point:

| Where it died | Recovery |
| --- | --- |
| preflight / publish, before the PR merged | `make release` again — a clean restart (close the stale PR if one was opened) |
| after the PR merged, before tagging | `make release` — publish self-skips (its build is already ahead of every tag) and the chain tags + distributes |
| partway through tagging | `make release-tag` — skips a done tag, creates a missing release for an existing tag |
| upload only (export ok, ASC upload flaked) | `make release-upload` — uploads the existing `dist/` package, no rebuild |
| archive / export | `make release-distribute-retry` — verifies the tag exists, then re-archives / exports / uploads without touching git, PR or tags |

## One-time setup

- **App Store Connect app record** for `fi.misaki.photodiary`, with an internal TestFlight group (automatic distribution on) containing the testers.
- **ASC API key**: App Store Connect → Users and Access → Integrations → App Store Connect API → generate (App Manager role). Put the `.p8` at `~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8`, then copy `Scripts/.asc-config.example` → `Scripts/.asc-config` (gitignored) and fill in the Key ID + Issuer ID.
- **Signing** is automatic (`-allowProvisioningUpdates`) against `DEVELOPMENT_TEAM` in `project.yml`; no manual certs.
