#!/usr/bin/env bash
# Archive, export, and upload the iOS app to App Store Connect. The last
# step of `make release` (see RELEASING.md); runnable alone to rebuild or
# re-upload the version + build currently in project.yml.
#
# Usage:
#   Scripts/distribute.sh                 # archive → export → upload
#   Scripts/distribute.sh --no-upload     # build the .ipa into dist/, skip the upload
#   Scripts/distribute.sh --upload-only   # upload the .ipa already in dist/
#
# One-time setup:
#   • App Store Connect → Users and Access → Integrations → App Store Connect
#     API → generate a key (App Manager role). Put the downloaded .p8 at
#     ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8 (altool finds it
#     by Key ID) and copy Scripts/.asc-config.example → Scripts/.asc-config
#     with the Key ID + Issuer ID. Both stay outside git.
#   • Signing is automatic against DEVELOPMENT_TEAM in project.yml, the same
#     way Xcode's Organizer does it; -allowProvisioningUpdates fetches the
#     distribution cert + profile on first run.
set -euo pipefail

cd "$(dirname "$0")/.."

upload=1
build=1
while [ $# -gt 0 ]; do
    case "$1" in
        --no-upload) upload=0 ;;
        --upload-only) build=0 ;;
        *) echo "error: unknown argument '$1'" >&2; exit 2 ;;
    esac
    shift
done
[ "$upload" -eq 1 ] || [ "$build" -eq 1 ] \
    || { echo "error: --no-upload and --upload-only are mutually exclusive." >&2; exit 2; }

project="PhotoDiary.xcodeproj"
scheme="PhotoDiary-iOS"
out="dist/ios"
archive="${out}/PhotoDiary-iOS.xcarchive"

if [ "$build" -eq 1 ]; then
    [ -d "$project" ] || { echo "error: $project missing — run Scripts/generate.sh first." >&2; exit 1; }
    marketing="$(awk -F'"' '/^ *MARKETING_VERSION:/ { print $2; exit }' project.yml)"
    build_number="$(awk -F'"' '/^ *CURRENT_PROJECT_VERSION:/ { print $2; exit }' project.yml)"
    rm -rf "$out"
    mkdir -p "$out"

    echo "▶︎ Archiving ${scheme} ${marketing} (${build_number})…"
    xcodebuild archive \
        -project "$project" \
        -scheme "$scheme" \
        -destination "generic/platform=iOS" \
        -archivePath "$archive" \
        -allowProvisioningUpdates \
        -quiet

    echo "▶︎ Exporting .ipa…"
    xcodebuild -exportArchive \
        -archivePath "$archive" \
        -exportPath "$out" \
        -exportOptionsPlist Scripts/ExportOptions.plist \
        -allowProvisioningUpdates \
        -quiet
fi

# Xcode names the .ipa after the product ("Photo Diary.ipa"); find it.
pkg="$( [ -d "$out" ] && /usr/bin/find "$out" -maxdepth 1 -name "*.ipa" | head -1 || true )"
[ -n "$pkg" ] || {
    if [ "$build" -eq 0 ]; then
        echo "error: no .ipa in $out to upload — run 'make distribute-build' first." >&2
    else
        echo "error: no .ipa produced in $out" >&2
    fi
    exit 1
}
echo "  → $pkg"

if [ "$upload" -eq 0 ]; then
    echo "✓ Built $pkg (upload skipped)."
    exit 0
fi

config="Scripts/.asc-config"
[ -f "$config" ] || {
    echo "error: $config missing. Copy Scripts/.asc-config.example to it and fill in" >&2
    echo "       your ASC API Key ID + Issuer ID (see this script's header)." >&2
    exit 1
}
# shellcheck disable=SC1090
. "$config"
: "${ASC_KEY_ID:?set ASC_KEY_ID in $config}"
: "${ASC_ISSUER_ID:?set ASC_ISSUER_ID in $config}"

echo "▶︎ Uploading to App Store Connect…"
xcrun altool --upload-app \
    --type ios \
    --file "$pkg" \
    --apiKey "$ASC_KEY_ID" \
    --apiIssuer "$ASC_ISSUER_ID"

echo "✓ Uploaded ${marketing:-} (${build_number:-}). Processing takes a few minutes; internal testers are notified automatically."
