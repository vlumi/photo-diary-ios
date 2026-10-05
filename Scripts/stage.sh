#!/usr/bin/env bash
# Launch the last simulator build staged for a screenshot (LaunchStage in
# PhotoDiaryCore): where it opens and what is on screen, from the variables
# below. A staged launch keeps its state in memory, so the simulator's own
# saved scope, tabs and todo pins are left as they were.
#   SCOPE=front|demo|<host>        the front page, or the instance to open (the
#                                  instance must be paired on this simulator)
#   GALLERY=<id>                   that instance's gallery as the scope
#   TAB=map|calendar
#   CAMERA=lat,lng,span            the map camera (or lat,lng,latSpan,lngSpan)
#   CALENDAR=<gallery>[/<year>[/<month>]]   the calendar opened that deep
#   PHOTO=<id>                     the viewer opened on it, once its month shows
#   PINS="lat,lng,note|…"          the todo pins on the map
#   SELECT=<map tag>|todo          a pin selected as by a tap (photo:<id>,
#                                  cluster:<id>; todo = the first pin)
#   SHEET=settings|pins            the front page's settings, the map's pin list
#   DEMO_LANG=en|ja                the app's language (the simulator's otherwise)
#   APPEARANCE=light|dark          the simulator's look (light unless asked)
#   DEVICE=<udid or name pattern>  the simulator (default: an iPhone 17 Pro Max,
#                                  the booted one first)
#   PD_UDID_FILE=<path>            the simulator's udid written there, for shoot.sh
set -euo pipefail
cd "$(dirname "$0")/.."

BUNDLE="fi.misaki.photodiary"
pat="${DEVICE:-iPhone 17 Pro Max}"

devices=$(xcrun simctl list devices available | grep -E "$pat" || true)
udid=$( { echo "$devices" | grep Booted; echo "$devices"; } \
    | grep -oE "[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}" | head -1)
[ -n "$udid" ] || { echo "No simulator matching /$pat/ installed." >&2; exit 1; }
xcrun simctl bootstatus "$udid" -b >/dev/null 2>&1 || true
open -a Simulator

# The pristine status bar, as for screenshots: 9:41, full battery.
offset=$(date +%z)
xcrun simctl status_bar "$udid" override \
    --time "2007-01-09T09:41:00.000${offset:0:3}:${offset:3}" \
    --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4 --dataNetwork wifi

app="$(find .build-xcode/Build/Products/Debug-iphonesimulator \
    -maxdepth 1 -name '*.app' -print -quit 2>/dev/null)"
[ -n "$app" ] && [ -d "$app" ] || { echo "Build the app first (make build)." >&2; exit 1; }

xcrun simctl ui "$udid" appearance "${APPEARANCE:-light}" >/dev/null 2>&1 || true
xcrun simctl terminate "$udid" "$BUNDLE" >/dev/null 2>&1 || true
# Installing over the app keeps its data: the paired instances stay.
xcrun simctl install "$udid" "$app"
xcrun simctl launch "$udid" "$BUNDLE" -photodiary-stage \
    ${SCOPE:+-photodiary-scope "$SCOPE"} ${GALLERY:+-photodiary-gallery "$GALLERY"} \
    ${TAB:+-photodiary-tab "$TAB"} ${CAMERA:+-photodiary-camera "$CAMERA"} \
    ${CALENDAR:+-photodiary-calendar "$CALENDAR"} ${PHOTO:+-photodiary-photo "$PHOTO"} \
    ${PINS:+-photodiary-pins "$PINS"} ${SELECT:+-photodiary-select "$SELECT"} \
    ${SHEET:+-photodiary-sheet "$SHEET"} \
    ${DEMO_LANG:+-AppleLanguages "($DEMO_LANG)"} >/dev/null
[ -n "${PD_UDID_FILE:-}" ] && echo "$udid" > "$PD_UDID_FILE"
echo "Staged launch on $udid."
