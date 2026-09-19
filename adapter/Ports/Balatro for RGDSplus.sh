#!/bin/sh
set -u
PORTS_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P) || exit 1
LAUNCHER="$PORTS_DIR/BalatroDual/launch.sh"
if [ ! -r "$LAUNCHER" ]; then
    printf '[Balatro for RGDSplus] Missing launcher: %s\n' "$LAUNCHER" >&2
    exit 127
fi
exec /bin/bash "$LAUNCHER" "$@"
