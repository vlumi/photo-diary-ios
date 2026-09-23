#!/usr/bin/env bash
# Regenerate the API client from the pinned server spec
# (Packages/PhotoDiaryCore/OpenAPI/openapi.json) with Apple's
# swift-openapi-generator. The output is committed, so a spec change
# shows up as a reviewable diff and the app's build, the release lane
# and CI never run the generator.
set -euo pipefail

cd "$(dirname "$0")/.."

spec_dir="Packages/PhotoDiaryCore/OpenAPI"
out_dir="Packages/PhotoDiaryCore/Sources/PhotoDiaryCore/Generated"

swift build -c release --package-path Tools/OpenAPIGenerator \
    --product swift-openapi-generator >/dev/null
generator="$(swift build -c release --package-path Tools/OpenAPIGenerator --show-bin-path)/swift-openapi-generator"

rm -rf "$out_dir"
mkdir -p "$out_dir"
"$generator" generate "$spec_dir/openapi.json" \
    --config "$spec_dir/openapi-generator-config.yaml" \
    --output-directory "$out_dir" \
    2>&1 | grep -E "warning|error" || true
echo "Generated $(cat "$out_dir"/*.swift | wc -l | tr -d ' ') lines into $out_dir"
