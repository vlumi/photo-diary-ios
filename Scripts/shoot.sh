#!/usr/bin/env bash
# App Store screenshot capture, hands-off: for every language and every shot in
# Scripts/asc/shots.json, relaunches the app staged for the shot (stage.sh),
# waits for it to settle, and captures. Output lands canonically named at
#   <OUT>/iphone/<lang>/<shot>-iphone.png
# ready for `make asc-screenshots`.
#   LANGS=en,ja                (default en,ja)
#   OUT=shots                  (default ./shots)
#   SETTLE=<seconds>           wait after launch before the capture (default 8;
#                              a live instance loads over the network)
#   PAUSE=1                    stop before each capture: ⏎ capture · r retake · s skip
#   ONLY=<name,name>           just these shots
#   INSTANCE=<host>            the instance shots.json's `instance` names otherwise
set -euo pipefail
cd "$(dirname "$0")/.."

LANGS="${LANGS:-en,ja}"
OUT="${OUT:-shots}"
SETTLE="${SETTLE:-8}"
BUNDLE="fi.misaki.photodiary"

make build >/dev/null

quit_app() {
    [ -n "${SIM_UDID:-}" ] && xcrun simctl terminate "$SIM_UDID" "$BUNDLE" >/dev/null 2>&1 || true
    return 0
}

# Stage one shot; $1 = language, the rest KEY=value stage variables.
launch() {
    local lang="$1"; shift
    local udid_file
    udid_file=$(mktemp)
    env DEMO_LANG="$lang" PD_UDID_FILE="$udid_file" "$@" Scripts/stage.sh >/dev/null
    SIM_UDID=$(cat "$udid_file")
    rm -f "$udid_file"
}

# One launch to put the app in front and quit it, so the first shot opens from
# the home screen: launched over another app, the status bar would carry a
# "◀ <that app>" link back to it.
launch en
quit_app

IFS=',' read -ra langs <<< "$LANGS"
total=$(python3 Scripts/asc/shots.py en --plain | wc -l | tr -d ' ')

for lang in "${langs[@]}"; do
    echo ""
    echo "━━━ iphone / $lang ━━━"
    i=0
    while IFS=$'\x1e' read -r name title args by_hand; do
        i=$((i + 1))
        if [ -n "${ONLY:-}" ] && ! [[ ",$ONLY," == *",$name,"* ]]; then continue; fi
        file="$OUT/iphone/$lang/${name}-iphone.png"
        echo "[$lang $i/$total] $name — $title"
        quit_app
        # Unit-separated by shots.py, so a value with spaces (a pin's note)
        # stays one argument.
        IFS=$'\x1f' read -ra stage_args <<< "$args"
        launch "$lang" ${stage_args[@]+"${stage_args[@]}"}
        sleep "$SETTLE"
        if [ -n "$by_hand" ] || [ -n "${PAUSE:-}" ]; then
            [ -n "$by_hand" ] && echo "  by hand: $by_hand"
            while :; do
                printf "  ⏎ capture · s skip · q quit: "
                read -r reply </dev/tty
                [ "$reply" = q ] && { quit_app; exit 0; }
                [ "$reply" = s ] && continue 2
                mkdir -p "$(dirname "$file")"
                xcrun simctl io "$SIM_UDID" screenshot --display=internal "$file" >/dev/null 2>&1
                printf "  saved %s — ⏎ next · r retake: " "$file"
                read -r again </dev/tty
                [ "$again" = r ] || break
            done
        else
            mkdir -p "$(dirname "$file")"
            xcrun simctl io "$SIM_UDID" screenshot --display=internal "$file" >/dev/null 2>&1
            echo "  saved $file"
        fi
    done < <(python3 Scripts/asc/shots.py "$lang" --plain)
    quit_app
done

echo ""
echo "Done. Sets under $OUT/iphone/ — \`make asc-screenshots\` shows the upload plan."
