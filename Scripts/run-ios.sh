#!/usr/bin/env bash
# Build + launch on an iPhone simulator. Usage: `make run` or
# `make run DEVICE="17 Pro"`. Picks the newest available iPhone
# simulator matching the app's deployment target; hint filters by
# device name (e.g. "17 Pro", "SE").
set -euo pipefail

cd "$(dirname "$0")/.."

hint="${1:-}"

# The app's minimum iOS from project.yml. We only consider simulators
# running this iOS major or newer — anything older can't run the app,
# and xcodebuild against an incompatible destination just hangs
# silently while it decides that.
min_ios_major="$(awk '
    /^  deploymentTarget:/ { in_dt = 1; next }
    in_dt && /^    iOS:/ {
        # Strip everything except digits before the first dot, e.g.
        # "26.0" -> "26". POSIX awk: no gsub-into-var + no match arrays.
        v = $0
        sub(/^[^"]*"/, "", v)
        sub(/\..*/, "", v)
        print v
        exit
    }
    in_dt && /^  [^ ]/ { in_dt = 0 }
' project.yml)"
if [[ -z "$min_ios_major" ]]; then
    echo "error: could not read deploymentTarget.iOS from project.yml." >&2
    exit 1
fi

# List every (runtime-id, device-name, udid, state) triple for iPhone
# simulators on iOS >= min_ios_major, one per line.
candidates_tsv="$(xcrun simctl list devices available -j \
    | python3 -c '
import json, re, sys
data = json.load(sys.stdin)
min_major = int(sys.argv[1])
rows = []
for runtime, devices in data["devices"].items():
    m = re.search(r"iOS-(\d+)(?:-(\d+))?", runtime)
    if not m: continue
    major = int(m.group(1))
    if major < min_major: continue
    minor = int(m.group(2) or 0)
    for d in devices:
        name = d.get("name", "")
        if not name.startswith("iPhone"): continue
        rows.append((major, minor, name, d["udid"], d.get("state", "Shutdown")))
# Sort by (major desc, minor desc, name) so the newest iOS wins.
rows.sort(key=lambda r: (-r[0], -r[1], r[2]))
for r in rows:
    print("\t".join(str(x) for x in r))
' "$min_ios_major")"

if [[ -z "$candidates_tsv" ]]; then
    echo "error: no iPhone simulator on iOS $min_ios_major+ is available." >&2
    echo "       Install a matching runtime (Xcode > Settings > Platforms)," >&2
    echo "       then create a device: xcrun simctl create 'iPhone 17 Pro' \\" >&2
    echo "         com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro \\" >&2
    echo "         com.apple.CoreSimulator.SimRuntime.iOS-${min_ios_major}-0" >&2
    exit 1
fi

# Optional device-name hint (e.g. "17 Pro", "SE"). Case-insensitive
# substring match on the name column.
if [[ -n "$hint" ]]; then
    filtered="$(echo "$candidates_tsv" | awk -F'\t' -v h="$hint" '
        tolower($3) ~ tolower(h) { print }
    ')"
    if [[ -z "$filtered" ]]; then
        echo "error: no simulator on iOS $min_ios_major+ matches hint: $hint" >&2
        echo "Available:" >&2
        echo "$candidates_tsv" | awk -F'\t' '{ printf "  %s (iOS %s.%s)\n", $3, $1, $2 }' >&2
        exit 1
    fi
    candidates_tsv="$filtered"
fi

# Prefer an already-booted candidate if there is one — cheaper.
picked="$(echo "$candidates_tsv" | awk -F'\t' '$5 == "Booted" { print; exit }')"
if [[ -z "$picked" ]]; then
    picked="$(echo "$candidates_tsv" | head -1)"
fi

IFS=$'\t' read -r ios_major ios_minor device_name udid state <<<"$picked"

echo "Launching on: $device_name (iOS $ios_major.$ios_minor, $udid)"

xcodebuild build -project PhotoDiary.xcodeproj -scheme PhotoDiary-iOS \
    -destination "platform=iOS Simulator,id=$udid" \
    -derivedDataPath .build-xcode -quiet

xcrun simctl boot "$udid" 2>/dev/null || true
open -a Simulator
app_path="$(find .build-xcode/Build/Products -name 'Photo Diary.app' -type d | head -1)"
xcrun simctl install "$udid" "$app_path"
xcrun simctl launch "$udid" fi.misaki.photodiary
