#!/usr/bin/env bash
# Release step 4 (pure): regenerate the project from the checked-out tree,
# then archive, export, and (unless --no-upload) upload via
# Scripts/distribute.sh. Builds straight from the checked-out release base,
# which is the tagged merge commit after the prior step.
#
# Usage: release-distribute.sh [--no-upload|--upload-only] [--require-tag]
#   --no-upload:   archive/export only, skip the ASC upload
#   --upload-only: upload the already-built dist/ package, skip archive/export
#   --require-tag: verify a tag exists for project.yml's current version+build
#                  (the standalone retry: only re-distribute a tagged release).
set -euo pipefail
cd "$(dirname "$0")/.."
. Scripts/release-lib.sh

mode=full
require_tag=0
while [ $# -gt 0 ]; do
    case "$1" in
        --no-upload) mode=no-upload ;;
        --upload-only) mode=upload-only ;;
        --require-tag) require_tag=1 ;;
        *) die "unknown argument '$1'" ;;
    esac
    shift
done

if [ "$require_tag" -eq 1 ]; then
    version="$(read_setting MARKETING_VERSION)"
    build="$(read_setting CURRENT_PROJECT_VERSION)"
    tag_exists "$version" "$build" \
        || die "no $(tag_for "$version" "$build") tag — nothing tagged to re-distribute. Run \`make release\` for a fresh cut."
    echo "✓ $(tag_for "$version" "$build") present — re-distributing."
fi

[ "$mode" = upload-only ] || Scripts/generate.sh >/dev/null

say "Distributing…"
case "$mode" in
    full)        Scripts/distribute.sh ;;
    no-upload)   Scripts/distribute.sh --no-upload ;;
    upload-only) Scripts/distribute.sh --upload-only ;;
esac

echo
case "$mode" in
    full)        echo "✓ distributed — uploaded to App Store Connect." ;;
    no-upload)   echo "✓ built — package in dist/ (upload skipped)." ;;
    upload-only) echo "✓ uploaded — existing dist/ package sent to App Store Connect." ;;
esac
