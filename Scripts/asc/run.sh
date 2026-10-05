#!/usr/bin/env bash
# Run the App Store Connect tooling in a self-managed venv, so the Makefile
# targets are one step. Bootstraps the venv on first use and refreshes it only
# when requirements.txt changes (a stamp file guards the reinstall).
#
# Usage: run.sh listing [--apply]
#        run.sh screens [--apply] [--dir <tree>]
#        run.sh shots <lang> [--plain]      (the shot list, for shoot.sh)
set -euo pipefail
cd "$(dirname "$0")"

VENV="${PHOTODIARY_ASC_VENV:-$HOME/.venvs/photodiary-asc}"
PY="$VENV/bin/python"
STAMP="$VENV/.requirements-stamp"

# Homebrew's Python is externally-managed; a venv is the correct install target.
if [ ! -x "$PY" ]; then
    echo "▶︎ Creating venv at $VENV …"
    python3 -m venv "$VENV"
fi
# (Re)install deps when requirements.txt is newer than the last install.
if [ ! -f "$STAMP" ] || [ requirements.txt -nt "$STAMP" ]; then
    echo "▶︎ Installing dependencies …"
    "$VENV/bin/pip" install --quiet --upgrade pip
    "$VENV/bin/pip" install --quiet -r requirements.txt
    touch "$STAMP"
fi

cmd="${1:-listing}"
shift || true
case "$cmd" in
    listing) exec "$PY" listing.py "$@" ;;
    screens) exec "$PY" screenshots.py "$@" ;;
    shots) exec python3 shots.py "$@" ;;
    *) echo "usage: run.sh {listing|screens|shots} [args]" >&2; exit 2 ;;
esac
