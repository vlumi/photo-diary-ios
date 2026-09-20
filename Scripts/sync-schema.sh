#!/usr/bin/env bash
# Fetch server/openapi.json from a specific vlumi/photo-diary tag and place
# it under Packages/PhotoDiaryCore/Sources/PhotoDiaryCore/Generated/, as a
# reference for checking a server change against the hand-written client
# (Remote/PhotoDiaryAPI.swift, Remote/WireModels.swift). Nothing is
# generated from it and no copy is checked in.
#
# Usage: `Scripts/sync-schema.sh v1.0.7` or `make sync-schema TAG=v1.0.7`

set -euo pipefail

cd "$(dirname "$0")/.."

tag="${1:-}"
if [[ -z "$tag" ]]; then
    echo "usage: $0 <server-tag>  (e.g. $0 v1.0.5)" >&2
    exit 2
fi

dest_dir="Packages/PhotoDiaryCore/Sources/PhotoDiaryCore/Generated"
dest_file="$dest_dir/openapi.json"
mkdir -p "$dest_dir"

url="https://raw.githubusercontent.com/vlumi/photo-diary/${tag}/server/openapi.json"
echo "Fetching $url"
curl -fsSL "$url" -o "$dest_file"

# Stamp the tag alongside the JSON so a reader (or CI check) can see
# which server version this snapshot was taken from.
printf '%s\n' "$tag" > "$dest_dir/openapi.tag"

echo "Wrote $dest_file"
echo "Pinned server tag: $tag"
