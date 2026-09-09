# Shared helpers for the release scripts (sourced, not executed).
#
# The release flow is split by concern: release-preflight.sh, release-publish.sh,
# release-tag.sh, release-distribute.sh — wired in order by the Makefile. The
# pure steps (preflight, tag, distribute) re-derive their inputs from git +
# project.yml so each runs standalone; only the dirty middle (publish: bump
# prompt + PR + CI-wait) carries in-memory state, all within one script.
#
# Mirrors the sibling apps' lane, minus the platform dimension: this app is
# iOS-only, so tags are plain vX.Y.Z-N and no script takes a platform.

# shellcheck shell=bash

PROJECT_FILE="project.yml"
CHANGELOG_FILE="CHANGELOG.md"
APP_ICON="Sources/iOS/Assets.xcassets/AppIcon.appiconset/AppIcon.png"

say() { printf '\033[36m▶︎ %s\033[0m\n' "$*"; }
die() { echo "error: $*" >&2; exit 1; }

# Retry a GitHub call a few times with backoff: a transient 502/timeout while
# polling a PR must not abort a release mid-flight. Returns the LAST attempt's
# exit code, so `gh pr checks` exit 8 (= pending) still reads as pending.
gh_retry() {
    local tries=0 max=5 rc=0
    while :; do
        "$@" && return 0
        rc=$?
        tries=$(( tries + 1 ))
        [ "$tries" -ge "$max" ] && return "$rc"
        echo "  (GitHub call failed, rc=$rc — retry $tries/$((max - 1)) in $(( tries * 2 ))s)" >&2
        sleep $(( tries * 2 ))
    done
}

# Make the local tags an exact mirror of origin's. The lane reads its state
# from the tags (resume guard, tag_exists, previous_tag), and origin is the
# copy that counts: a tag deleted there to redo a failed cut must stop
# counting here too, or publish re-bumps and tag refuses to re-tag. Tags are
# only ever created by the lane and pushed at once, so a local-only tag is
# always stale, never unpublished work.
sync_tags() {
    git fetch --quiet --prune origin '+refs/tags/*:refs/tags/*'
}

# Stamp the changelog's "Unreleased (next build)" section with a build number
# at release time: the human-written entries accumulated there get promoted to
# a `### build N — <date>` heading and a fresh empty Unreleased takes their
# place. No-op (exit 0, nothing staged) when Unreleased has no entries, so a
# build with only internal changes doesn't get an empty heading.
#
# Writes the `## vX.Y.Z` heading too, when the version changed — the version
# is known here, and a hand-set heading in an otherwise automatic lane is the
# step that gets forgotten.
promote_changelog_build() {
    local build="$1"
    local version="${2:-}"
    local heading="### Unreleased (next build)"
    [ -f "$CHANGELOG_FILE" ] || { say "no $CHANGELOG_FILE — skipping changelog stamp."; return 0; }

    awk '
        f && /^#/ { exit 1 }
        f && /^[[:space:]]*-[[:space:]]/ { exit 0 }
        $0 == h { f = 1 }
    ' h="$heading" "$CHANGELOG_FILE" || {
        echo "  (Unreleased has no entries — nothing to promote)"
        return 0
    }

    local today; today="$(date +%Y-%m-%d)"
    local tmp; tmp="$(mktemp)"
    # Same version: promote in place under the open `## vX.Y.Z`. New version:
    # open a new `## vNEW` section (fresh Unreleased + this build) above, and
    # re-open the old `## vOLD` heading just before its previous build so it
    # still covers everything it shipped.
    awk -v build="$build" -v today="$today" -v version="$version" '
        version != "" && !done && /^## v[0-9]/ {
            old = $0
            print "## v" version "\n"
            print h "\n"
            print "### build " build " — " today
            done = 1
            next
        }
        old != "" && $0 == h { eat_blank = 1; next }
        eat_blank && /^$/ { eat_blank = 0; next }
        old != "" && /^### build / {
            print old "\n"
            old = ""
            print
            next
        }
        $0 == h && !done {
            print h "\n\n### build " build " — " today
            done = 1
            next
        }
        { print }
    ' h="$heading" "$CHANGELOG_FILE" > "$tmp"
    mv "$tmp" "$CHANGELOG_FILE"
    git add "$CHANGELOG_FILE"
    if [ -n "$version" ]; then
        echo "  promoted Unreleased → v${version} build ${build}"
    else
        echo "  promoted Unreleased → build ${build}"
    fi
}

# The branch a release is cut from: main, or a version-line release branch
# (release/X.Y.x — a patch on a shipped version after main moved on). The
# lane's own PR branches are release/vX.Y.Z-N (always v-prefixed) and are
# never a base.
release_base() {
    local b; b="$(git rev-parse --abbrev-ref HEAD)"
    case "$b" in
        release/v*) die "on '$b' — the release lane's own PR branch, not a base. Check out main (or the version-line release branch) first." ;;
        main|release/*) printf '%s' "$b" ;;
        *) die "not on a release base (on '$b') — release from main or a version-line release/… branch." ;;
    esac
}

# The quoted value of a setting in project.yml.
read_setting() {
    local key="$1" val
    val="$(grep -oE "${key}: *\"[^\"]+\"" "$PROJECT_FILE" | head -1 | grep -oE '"[^"]+"' | tr -d '"')"
    [ -n "$val" ] || die "no ${key} found in $PROJECT_FILE"
    printf '%s' "$val"
}

# The highest build number N across all vX.Y.Z-N tags, or 0 if none. Lets
# publish tell "main is a bumped-but-untagged tip" from a fresh release without
# a state file — the tags are the record.
highest_tagged_build() {
    local n max=0
    while IFS= read -r n; do [ "$n" -gt "$max" ] && max="$n"; done < <(
        git tag --list 'v*' | grep -oE -- '-[0-9]+$' | tr -d '-')
    printf '%s' "$max"
}

tag_for() { printf 'v%s-%s' "$1" "$2"; }
tag_exists() { git rev-parse --verify "$(tag_for "$1" "$2")" >/dev/null 2>&1; }

# The previous release tag to diff notes against: the highest tag not newer
# than this release (and not itself). Tags MUST be vMAJOR.MINOR.PATCH-BUILD —
# the suffix is a plain build number, never -beta.N, or `-v:refname` mis-sorts.
previous_tag() {
    local version="$1" build="$2"
    local this; this="$(tag_for "$version" "$build")"
    local this_key; this_key="$(tag_sort_key "$this")"
    local t k
    while IFS= read -r t; do
        [ "$t" = "$this" ] && continue
        k="$(tag_sort_key "$t")"
        if [ "$k" -le "$this_key" ]; then printf '%s' "$t"; return; fi
    done < <(git tag --list 'v*' --sort=-v:refname)
}

# A sortable integer for a vX.Y.Z-N tag: X*1e12 + Y*1e8 + Z*1e4 + N.
tag_sort_key() {
    local v="${1#v}"
    local ver="${v%-*}" build="${v##*-}"
    local maj="${ver%%.*}"
    local rest="${ver#*.}"
    local min="${rest%%.*}"
    local pat="${rest#*.}"
    printf '%d' "$(( maj * 1000000000000 + min * 100000000 + pat * 10000 + build ))"
}

gh_release_exists() { gh release view "$1" >/dev/null 2>&1; }
