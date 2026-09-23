#!/usr/bin/env bash
# Pin the server's OpenAPI document at a vlumi/photo-diary release tag.
#
# Two pins. The default is the newest server: its document is what the
# API client is generated from (Packages/PhotoDiaryCore/OpenAPI/), so
# the client is regenerated right after, and the compiler then holds the
# app to that release. `min` is the oldest server the app supports
# (Tests/…/Fixtures/openapi-min.json): ServerContractTests checks that
# the app calls and decodes only what that one already offered, so move
# it only when dropping support for older servers. Either is a
# deliberate step with a reviewable diff.
#
# Usage: `Scripts/sync-schema.sh v1.1.1` or `make sync-schema TAG=v1.1.1`
#        `Scripts/sync-schema.sh v1.0.7 min` or `make sync-schema TAG=v1.0.7 PIN=min`

set -euo pipefail

cd "$(dirname "$0")/.."

tag="${1:-}"
if [[ -z "$tag" ]]; then
    echo "usage: $0 <server-tag> [min]  (e.g. $0 v1.1.1)" >&2
    exit 2
fi
case "${2:-}" in
    "") dest_file="Packages/PhotoDiaryCore/OpenAPI/openapi.json" ;;
    min) dest_file="Packages/PhotoDiaryCore/Tests/PhotoDiaryCoreTests/Fixtures/openapi-min.json" ;;
    *) echo "error: the second argument can only be 'min'." >&2; exit 2 ;;
esac
mkdir -p "$(dirname "$dest_file")"

url="https://raw.githubusercontent.com/vlumi/photo-diary/${tag}/server/openapi.json"
echo "Fetching $url"
curl -fsSL "$url" -o "$dest_file"
echo "Pinned server tag: $tag in $dest_file"

if [[ -z "${2:-}" ]]; then
    Scripts/generate-client.sh
fi
echo "Run \`make test\` to check the client against it."
