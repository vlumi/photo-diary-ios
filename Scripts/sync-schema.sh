#!/usr/bin/env bash
# Pin the server's OpenAPI document: fetch server/openapi.json from a
# vlumi/photo-diary tag into the Core tests' fixtures, where
# ServerContractTests checks the hand-written client against it
# (Remote/APIRoute.swift, the wire models, the session cookies).
#
# Two pins. The default is the newest server the app is checked
# against. `min` is the oldest server the app supports: the client may
# rely only on what that one already offered, so move it only when
# dropping support for older servers. Bumping either is a deliberate
# step with a reviewable diff.
#
# Usage: `Scripts/sync-schema.sh v1.1.0` or `make sync-schema TAG=v1.1.0`
#        `Scripts/sync-schema.sh v1.0.7 min` or `make sync-schema TAG=v1.0.7 PIN=min`

set -euo pipefail

cd "$(dirname "$0")/.."

tag="${1:-}"
if [[ -z "$tag" ]]; then
    echo "usage: $0 <server-tag> [min]  (e.g. $0 v1.0.9)" >&2
    exit 2
fi
case "${2:-}" in
    "") name="openapi.json" ;;
    min) name="openapi-min.json" ;;
    *) echo "error: the second argument can only be 'min'." >&2; exit 2 ;;
esac

dest_dir="Packages/PhotoDiaryCore/Tests/PhotoDiaryCoreTests/Fixtures"
dest_file="$dest_dir/$name"
mkdir -p "$dest_dir"

url="https://raw.githubusercontent.com/vlumi/photo-diary/${tag}/server/openapi.json"
echo "Fetching $url"
curl -fsSL "$url" -o "$dest_file"

echo "Wrote $dest_file"
echo "Pinned server tag: $tag — run \`make test\` to check the client against it."
