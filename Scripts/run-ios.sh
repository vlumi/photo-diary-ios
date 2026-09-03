#!/usr/bin/env bash
# Build + launch on an iPhone simulator. Usage: `make run` or
# `make run DEVICE="17 Pro"`. Picks a booted simulator matching the
# hint if one exists; otherwise boots the newest iPhone Simulator.
set -euo pipefail

cd "$(dirname "$0")/.."

hint="${1:-}"

# Prefer a simulator that's already booted (matches hint if given).
booted="$(xcrun simctl list devices booted | grep -oE 'iPhone [^\(]+' | head -1 || true)"
if [[ -n "$booted" ]]; then
    if [[ -z "$hint" ]] || echo "$booted" | grep -qi "$hint"; then
        device_name="$(echo "$booted" | xargs)"
    fi
fi

# Otherwise, pick from available iPhone Simulators.
if [[ -z "${device_name:-}" ]]; then
    if [[ -n "$hint" ]]; then
        device_name="$(xcrun simctl list devices available | grep -oE "iPhone [^\(]*$hint[^\(]*" | head -1 | xargs || true)"
    fi
    if [[ -z "${device_name:-}" ]]; then
        # Fall back to the newest available iPhone.
        device_name="$(xcrun simctl list devices available | grep -oE 'iPhone [^\(]+' | tail -1 | xargs)"
    fi
fi

if [[ -z "${device_name:-}" ]]; then
    echo "error: no iPhone simulator available." >&2
    exit 1
fi

echo "Launching on: $device_name"
xcodebuild build -project PhotoDiary.xcodeproj -scheme PhotoDiary-iOS \
    -destination "platform=iOS Simulator,name=$device_name" \
    -derivedDataPath .build-xcode -quiet

# Boot + install + launch.
udid="$(xcrun simctl list devices available | grep "$device_name " | grep -oE '[A-F0-9-]{36}' | head -1)"
xcrun simctl boot "$udid" 2>/dev/null || true
open -a Simulator
app_path="$(find .build-xcode/Build/Products -name 'Photo Diary.app' -type d | head -1)"
xcrun simctl install "$udid" "$app_path"
xcrun simctl launch "$udid" fi.misaki.photodiary
