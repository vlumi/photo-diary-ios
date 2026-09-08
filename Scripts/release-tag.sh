#!/usr/bin/env bash
# Release step 3 (pure): tag the released commit and publish a GitHub release.
# Re-derives everything from durable state — version/build from the merged
# project.yml on the release base, the commit from that base's tip — so it
# needs nothing passed in and is safe to re-run (it refuses to clobber an
# existing tag). Tags are vX.Y.Z-N (no beta/rc).
set -euo pipefail
cd "$(dirname "$0")/.."
. Scripts/release-lib.sh

base="$(release_base)"
say "Refreshing ${base}…"
git pull --quiet --ff-only origin "$base"
version="$(read_setting MARKETING_VERSION)"
build="$(read_setting CURRENT_PROJECT_VERSION)"
merge_sha="$(git rev-parse HEAD)"
git log -1 --pretty=%s | grep -q "Merge pull request" \
    || echo "  note: ${base} tip isn't a merge commit (subject: $(git log -1 --pretty=%s)) — tagging it anyway."
tag="$(tag_for "$version" "$build")"
echo "tagging ${tag} at ${merge_sha:0:7}"

# Idempotent: tag + release exist → skip; tag only → create the release;
# neither → tag then release.
if tag_exists "$version" "$build" && gh_release_exists "$tag"; then
    echo "  $tag already tagged + released — skipping."
    exit 0
fi
if tag_exists "$version" "$build"; then
    echo "  $tag already tagged; creating its GitHub release."
else
    git tag -a "$tag" "$merge_sha" -m "Photo Diary iOS v${version} (build ${build})"
    git push --quiet origin "$tag"
    echo "  tagged $tag → ${merge_sha:0:7}"
fi

# Notes: commit subjects since the previous release tag.
prev="$(previous_tag "$version" "$build")"
if [ -n "$prev" ]; then
    notes_changes="$(git log --no-merges --pretty='- %s' "${prev}..${merge_sha}")"
    since=" since ${prev}"
else
    notes_changes="- Initial release."
    since=""
fi
notes="$(cat <<EOF
Photo Diary iOS ${version} build ${build}.

| | |
|---|---|
| Marketing version | ${version} |
| Apple build number | ${version} (${build}) |
| Commit | ${merge_sha:0:7} |

**Changes${since}**
${notes_changes}
EOF
)"
# "latest" only when this tag really is the highest, so a patch cut on an
# old version from a release/X.Y.x branch doesn't steal it.
latest=false
[ "$(git tag --list 'v*' --sort=-v:refname | head -1)" = "$tag" ] && latest=true
gh release create "$tag" --verify-tag \
    --title "v${version} (build ${build})" \
    --notes "$notes" --latest="$latest" >/dev/null
echo "✓ tagged + released $tag (latest=$latest)."
