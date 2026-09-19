#!/bin/bash
set -u
APP_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P) || exit 1
export BALATRO_RGDS_ROOT="$APP_DIR"
unset BALATRO_RGDS_TEST BALATRO_DUAL_TEST BALATRO_DUAL_FIXTURE BALATRO_IMPORT_TEST
unset BALATRO_PM_PERF_HUD BALATRO_DUAL_BACKGROUND_MOTION
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/var/run}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
export SDL_VIDEODRIVER=wayland
export SDL_VIDEO_DOUBLE_BUFFER=1
export SDL_RENDER_VSYNC=1
export LOVE_GRAPHICS_USE_OPENGLES=1
export SDL_AUDIODRIVER=pulse
export ALSOFT_DRIVERS=pulse
export PULSE_SERVER=unix:/tmp/pulse-socket
export LD_LIBRARY_PATH="$APP_DIR/runtime/libs.aarch64:/usr/lib:/lib"
export BALATRO_PM_PERF_OPTIMIZATIONS=1
export BALATRO_PM_FPS_CAP="${BALATRO_PM_FPS_CAP:-60}"
export XDG_DATA_HOME="$APP_DIR/saves"
export XDG_CONFIG_HOME="$APP_DIR/saves"
mkdir -p "$APP_DIR/logs" "$APP_DIR/cache" "$XDG_DATA_HOME" || exit 1
export BALATRO_RGDS_SESSION="$APP_DIR/logs/$(date +%Y%m%d-%H%M%S)-$$"
LOG="$BALATRO_RGDS_SESSION.log"
printf '%s\n' "$LOG" > "$APP_DIR/logs/latest-path.txt"
exec >> "$LOG" 2>&1
printf '[launcher] date=%s\n' "$(date -Iseconds)"
printf '[launcher] app=%s\n' "$APP_DIR"
printf '[launcher] firmware='
uname -a
cat "$APP_DIR/build-manifest.json"
if [ ! -f "$APP_DIR/runtime/love.aarch64" ]; then
    echo "[launcher] Missing ARM64 runtime."
    exit 2
fi
# FAT/exFAT extraction may not preserve archive executable permission bits.
chmod +x "$APP_DIR/runtime/love.aarch64" 2>/dev/null || true
BUILD_ID=$(cat "$APP_DIR/installer/build-id.txt") || exit 2
case "$BUILD_ID" in
    *[!a-f0-9]*|"") echo "[launcher] Invalid build ID."; exit 2 ;;
esac
[ "${#BUILD_ID}" -eq 64 ] || exit 2
GAME_DIR="$APP_DIR/cache/love/balatro-dual-installer/builds/$BUILD_ID/game"
cd "$APP_DIR" || exit 1
. "$APP_DIR/dual_touch.sh"
# The installer writes only to its cache identity, never the player's save identity.
XDG_DATA_HOME="$APP_DIR/cache" XDG_CONFIG_HOME="$APP_DIR/cache" \
    "$APP_DIR/runtime/love.aarch64" "$APP_DIR/installer" &
INSTALL_PID=$!
trap 'kill -TERM "$INSTALL_PID" 2>/dev/null || true' TERM INT
wait "$INSTALL_PID"
rc=$?
if kill -0 "$INSTALL_PID" 2>/dev/null; then
    wait "$INSTALL_PID"
    rc=$?
fi
if [ "$rc" -ne 0 ] || [ ! -f "$GAME_DIR/main.lua" ] || \
   [ "$(cat "$GAME_DIR/../ready.txt" 2>/dev/null)" != "$BUILD_ID" ]; then
    echo "[launcher] Installer did not produce a verified game (exit=$rc)."
    exit 2
fi
"$APP_DIR/runtime/love.aarch64" "$GAME_DIR" &
GAME_PID=$!
printf '%s\n' "$GAME_PID" > "$APP_DIR/logs/game.pid"
(
    while kill -0 "$GAME_PID" 2>/dev/null; do
        printf '\n[resources] %s\n' "$(date -Iseconds)"
        awk '/^(VmRSS|VmHWM|VmSize|Threads):/ {print}' "/proc/$GAME_PID/status" 2>/dev/null
        awk '/^(MemAvailable|SwapFree):/ {print}' /proc/meminfo
        sleep 10
    done
) >> "$BALATRO_RGDS_SESSION.resources.log" 2>&1 &
MONITOR_PID=$!
trap 'kill -TERM "$GAME_PID" 2>/dev/null || true' TERM INT
wait "$GAME_PID"
rc=$?
if kill -0 "$GAME_PID" 2>/dev/null; then
    wait "$GAME_PID"
    rc=$?
fi
kill -TERM "$MONITOR_PID" 2>/dev/null || true
wait "$MONITOR_PID" 2>/dev/null || true
printf '[launcher] love_exit_rc=%s date=%s\n' "$rc" "$(date -Iseconds)"
if [ "$rc" -ne 0 ]; then
    {
        printf 'exit_code=%s\n' "$rc"
        tail -120 "$LOG"
        echo '[kernel tail]'
        dmesg | tail -80
    } > "$BALATRO_RGDS_SESSION.crash.txt" 2>&1
fi
sync
exit "$rc"
