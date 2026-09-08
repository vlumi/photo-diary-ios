#!/usr/bin/env bash
# Release step 1 (pure): refuse to start unless we're on a clean release base
# (main, or a release/X.Y.x maintenance branch — see release_base) that
# matches origin, with gh + xcodegen available and an opaque app icon — so the
# commit we eventually tag and build is exactly what lands on the base.
# Mutates nothing; safe to run anytime.
set -euo pipefail
cd "$(dirname "$0")/.."
. Scripts/release-lib.sh

command -v gh >/dev/null || die "gh CLI not found (needed to open + merge the PR)."
command -v xcodegen >/dev/null || die "xcodegen not found (brew install xcodegen)."
[ -z "$(git status --porcelain)" ] || die "working tree not clean — commit or stash first."

# App Store Connect refuses an icon with an alpha channel (the upload
# silently never shows up), so guard it here rather than find out after
# a full archive.
[ -f "$APP_ICON" ] || die "app icon not found at $APP_ICON."
if sips -g hasAlpha "$APP_ICON" 2>/dev/null | grep -q "hasAlpha: yes"; then
    die "app icon has an alpha channel — ASC will reject it. Flatten it to opaque."
fi

base="$(release_base)"
say "Fetching origin…"
git fetch --quiet origin "$base"
[ "$(git rev-parse HEAD)" = "$(git rev-parse "origin/$base")" ] \
    || die "local ${base} differs from origin/${base} — pull/push to sync first."
echo "✓ preflight: on a clean ${base} matching origin."
