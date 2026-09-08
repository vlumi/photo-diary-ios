#!/usr/bin/env bash
# Release step 2 (the dirty middle): the interactive + stateful core. Bumps
# the version/build (with a prompt), stamps the changelog, opens a PR, and
# blocks until CI passes and it merges. All cross-step state lives here in
# memory; the pure steps that follow (tag, distribute) read the result back
# from the merged commit on the release base.
#
# Versioning (project.yml):
#   • MARKETING_VERSION — asked on every release; blank keeps it.
#   • CURRENT_PROJECT_VERSION — the build number, always one past both the
#     base's current build and the highest existing tag.
#
# On CI failure it stops with the PR left open: no merge, and (since the
# later steps never run) no tag, build, or upload.
set -euo pipefail
cd "$(dirname "$0")/.."
. Scripts/release-lib.sh

base="$(release_base)"

cur_version="$(read_setting MARKETING_VERSION)"
cur_build="$(read_setting CURRENT_PROJECT_VERSION)"
echo "current: version ${cur_version}, build ${cur_build}"

# Resume guard: if the base's build is already ahead of every tag, a previous
# run's bump merged but wasn't tagged — publishing is done. Skip to tag.
if [ "$cur_build" -gt "$(highest_tagged_build)" ]; then
    echo "✓ build ${cur_build} already merged to ${base} but untagged — publish already done, skipping to tag."
    exit 0
fi

new_version="$cur_version"
IFS='.' read -r MA MI PA <<EOF
${cur_version}
EOF
suggested="${MA}.${MI}.$(( ${PA:-0} + 1 ))"
minor_suggested="${MA}.$(( ${MI:-0} + 1 )).0"
printf 'Bump marketing version? current %s — blank = keep, "p" = %s, "m" = %s, or X.Y.Z: ' \
    "$cur_version" "$suggested" "$minor_suggested"
read -r answer || answer=""
case "$answer" in
    "")  new_version="$cur_version" ;;
    p|P) new_version="$suggested" ;;
    m|M) new_version="$minor_suggested" ;;
    *)   [[ "$answer" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] \
             || die "version must be X.Y.Z (got '$answer')"
         new_version="$answer" ;;
esac
highest="$(highest_tagged_build)"
new_build=$(( (cur_build > highest ? cur_build : highest) + 1 ))
echo "release: version ${new_version}, build ${new_build}"

if [ "$new_version" != "$cur_version" ]; then
    sed -i '' -E "s/(MARKETING_VERSION: *)\"[^\"]+\"/\1\"${new_version}\"/" "$PROJECT_FILE"
fi
sed -i '' -E "s/(CURRENT_PROJECT_VERSION: *)\"[0-9]+\"/\1\"${new_build}\"/" "$PROJECT_FILE"
[ "$(read_setting MARKETING_VERSION)" = "$new_version" ] || die "version not applied."
[ "$(read_setting CURRENT_PROJECT_VERSION)" = "$new_build" ] || die "build not applied."

say "Stamping the changelog…"
if [ "$new_version" != "$cur_version" ]; then
    promote_changelog_build "$new_build" "$new_version"
else
    promote_changelog_build "$new_build"
fi

rel_branch="release/v${new_version}-${new_build}"
git rev-parse --verify "$rel_branch" >/dev/null 2>&1 && die "branch '$rel_branch' already exists."
git checkout -q -b "$rel_branch"
git add "$PROJECT_FILE" "$CHANGELOG_FILE"
git commit --quiet -m "$(cat <<EOF
Release v${new_version} build ${new_build}

Marketing version ${new_version}, build ${new_build}. The changelog
Unreleased section is stamped as build ${new_build}. Opened by
Scripts/release-publish.sh, which tags this merge commit and distributes
once CI passes.
EOF
)"
git push --quiet -u origin "$rel_branch"

say "Opening PR (into ${base})…"
gh pr create \
    --title "Release v${new_version} build ${new_build}" \
    --body "Version **${new_version}**, build **${new_build}**. Opened by \`Scripts/release-publish.sh\`; merges once CI passes. The resulting merge commit on ${base} is tagged and distributed." \
    --base "$base" --head "$rel_branch" >/dev/null

# Auto-merge needs branch protection with required checks; without it GitHub
# refuses to arm it (the PR is already mergeable). Fall back to merging
# directly after the CI wait below, so green-before-merge holds either way.
say "Enabling auto-merge (merge commit) — will merge when CI passes…"
automerge=1
if ! gh pr merge "$rel_branch" --auto --merge 2>/dev/null; then
    automerge=0
    echo "  (auto-merge unavailable on ${base} — will merge directly once CI passes)"
fi

say "Waiting for CI to register…"
tries=0
while true; do
    gh pr checks "$rel_branch" >/dev/null 2>&1 && break
    rc=$?
    [ "$rc" -eq 8 ] && break
    tries=$(( tries + 1 ))
    [ "$tries" -ge 12 ] && die "no CI checks registered after ~60s — PR left open at $rel_branch."
    sleep 5
done
say "Waiting for CI to finish…"
if ! gh pr checks "$rel_branch" --watch --fail-fast; then
    die "CI failed — PR left open at $rel_branch. No merge, tag, build, or upload was done."
fi

say "Confirming merge…"
[ "$automerge" -eq 1 ] || gh pr merge "$rel_branch" --merge >/dev/null

# Auto-merge is async: GitHub merges a few seconds after checks go green.
state=""
for _ in $(seq 1 20); do
    state="$(gh pr view "$rel_branch" --json state --jq .state)"
    [ "$state" = "MERGED" ] && break
    sleep 3
done
[ "$state" = "MERGED" ] || die "PR is '$state' after waiting, not MERGED. Once it merges, re-run \`make release\` — it detects the merged-but-untagged build and resumes at the tag step."

git checkout -q "$base"
git pull --quiet --ff-only origin "$base"

echo "✓ published: v${new_version} build ${new_build} merged to ${base}."
