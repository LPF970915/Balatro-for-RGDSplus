# Sourced by the dual launcher. Match the firmware's touchscreen application mode.
TOUCH_CONTROL=/sys/class/anbernic_misc/tpctrl
TOUCH_PREVIOUS=
if [ -r "$TOUCH_CONTROL" ] && [ -w "$TOUCH_CONTROL" ]; then
    TOUCH_PREVIOUS=$(cat "$TOUCH_CONTROL")
    case "$TOUCH_PREVIOUS" in
        0|1)
            if printf '0\n' > "$TOUCH_CONTROL"; then
                printf '[touch] tpctrl_before=%s active=%s\n' "$TOUCH_PREVIOUS" "$(cat "$TOUCH_CONTROL")"
            else
                echo '[touch] tpctrl enable failed'
                TOUCH_PREVIOUS=
            fi
            ;;
        *) echo '[touch] unknown tpctrl value; unchanged'; TOUCH_PREVIOUS= ;;
    esac
else
    echo '[touch] tpctrl unavailable'
fi
restore_touch_control() {
    if [ -n "$TOUCH_PREVIOUS" ] && [ "$(cat "$TOUCH_CONTROL" 2>/dev/null)" = 0 ]; then
        printf '%s\n' "$TOUCH_PREVIOUS" > "$TOUCH_CONTROL"
        printf '[touch] tpctrl_restored=%s\n' "$TOUCH_PREVIOUS"
    fi
}
trap restore_touch_control EXIT
