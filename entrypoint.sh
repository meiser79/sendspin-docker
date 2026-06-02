#!/usr/bin/env bash
set -euo pipefail

# Utility mode: list available audio devices
if [ "${1:-}" = "list-devices" ]; then
    echo "=== ALSA devices (aplay -l) ==="
    aplay -l 2>/dev/null || echo "(no ALSA devices found)"
    echo ""
    echo "=== Sendspin audio devices ==="
    sendspin --list-audio-devices 2>/dev/null || true
    exit 0
fi

# Derive a stable client ID from SENDSPIN_NAME if not explicitly set
if [ -z "${SENDSPIN_CLIENT_ID}" ]; then
    SENDSPIN_CLIENT_ID=$(echo "${SENDSPIN_NAME}" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/-$//')
fi

# Auto-detect audio device if not specified
if [ -z "${SENDSPIN_AUDIO_DEVICE}" ]; then
    DETECTED=$(sendspin --list-audio-devices 2>/dev/null \
        | grep -E '^\s+\[[0-9]+\]' \
        | grep -iv 'default\|sysdefault\|dmix\|null' \
        | head -1 \
        | grep -oE '\[[0-9]+\]' \
        | tr -d '[]')
    if [ -n "${DETECTED}" ]; then
        SENDSPIN_AUDIO_DEVICE="${DETECTED}"
        echo "  Auto-detected audio device: ${DETECTED}"
    else
        echo "  No device detected, using sendspin default"
    fi
fi

SENDSPIN_CLI_VERSION="$(sendspin --version 2>/dev/null | head -n1 || echo unknown)"

# Build the command
CMD=(sendspin daemon)
CMD+=(--name "${SENDSPIN_NAME}")

[ -n "${SENDSPIN_CLIENT_ID}" ]        && CMD+=(--id "${SENDSPIN_CLIENT_ID}")
[ -n "${SENDSPIN_AUDIO_DEVICE}" ]     && CMD+=(--audio-device "${SENDSPIN_AUDIO_DEVICE}")
[ -n "${SENDSPIN_SERVER_URL}" ]       && CMD+=(--url "${SENDSPIN_SERVER_URL}")
[ -n "${SENDSPIN_AUDIO_FORMAT}" ]     && CMD+=(--audio-format "${SENDSPIN_AUDIO_FORMAT}")
[ -n "${SENDSPIN_STATIC_DELAY_MS}" ]  && CMD+=(--static-delay-ms "${SENDSPIN_STATIC_DELAY_MS}")
[ -n "${SENDSPIN_HOOK_START}" ]       && CMD+=(--hook-start "${SENDSPIN_HOOK_START}")
[ -n "${SENDSPIN_HOOK_STOP}" ]        && CMD+=(--hook-stop "${SENDSPIN_HOOK_STOP}")
[ -n "${SENDSPIN_HOOK_SET_VOLUME}" ]  && CMD+=(--hook-set-volume "${SENDSPIN_HOOK_SET_VOLUME}")
[ -n "${SENDSPIN_PORT}" ]             && CMD+=(--port "${SENDSPIN_PORT}")
[ -n "${SENDSPIN_MANUFACTURER}" ]     && CMD+=(--manufacturer "${SENDSPIN_MANUFACTURER}")
[ -n "${SENDSPIN_PRODUCT_NAME}" ]     && CMD+=(--product-name "${SENDSPIN_PRODUCT_NAME}")

CMD+=(--hardware-volume "${SENDSPIN_HARDWARE_VOLUME}")
CMD+=(--log-level "${SENDSPIN_LOG_LEVEL}")
CMD+=(--disable-mpris)

# Build the ffmpeg command
FFMPEG_CMD=(ffmpeg -hide_banner -nostdin -loglevel "${FFMPEG_STREAM_LOGLEVEL}" -f alsa -vn)

[ -n "${FFMPEG_STREAM_AUDIO_DEVICE}" ]  && FFMPEG_CMD+=(-i "${FFMPEG_STREAM_AUDIO_DEVICE}")
[ -n "${FFMPEG_STREAM_CODEC}" ]         && FFMPEG_CMD+=(-acodec "${FFMPEG_STREAM_CODEC}")
[ -n "${FFMPEG_STREAM_BITRATE}" ]       && FFMPEG_CMD+=(-b:a "${FFMPEG_STREAM_BITRATE}")
[ -n "${FFMPEG_STREAM_SAMPLE_RATE}" ]   && FFMPEG_CMD+=(-ar "${FFMPEG_STREAM_SAMPLE_RATE}")
[ -n "${FFMPEG_STREAM_CHANNELS}" ]      && FFMPEG_CMD+=(-ac "${FFMPEG_STREAM_CHANNELS}")
[ -n "${FFMPEG_STREAM_FORMAT}" ]        && FFMPEG_CMD+=(-f "${FFMPEG_STREAM_FORMAT}")
[ -n "${FFMPEG_STREAM_CONTENT_TYPE}" ]  && FFMPEG_CMD+=(-content_type "${FFMPEG_STREAM_CONTENT_TYPE}")

FFMPEG_CMD+=(-listen 1 http://0.0.0.0:${FFMPEG_STREAM_PORT}${FFMPEG_STREAM_PATH})

echo "───────────────────────────────────────"
echo "  Name:   ${SENDSPIN_NAME}"
echo "  ID:     ${SENDSPIN_CLIENT_ID}"
echo "  Device: ${SENDSPIN_AUDIO_DEVICE:-auto}"
echo "  Port:   ${SENDSPIN_PORT}"
echo ""
echo "  Container Version: ${SENDSPIN_DOCKER_VERSION}"
echo "  Sendspin CLI:      ${SENDSPIN_CLI_VERSION}"
echo ""
echo "  CMD: ${CMD[*]}"
echo "  FFMPEG_CMD: ${FFMPEG_CMD[*]}"
echo "───────────────────────────────────────"
echo ""

cleanup() {
    trap - TERM INT EXIT
    [ -n "${SENDSPIN_PID:-}" ] && kill "${SENDSPIN_PID}" 2>/dev/null || true
    [ -n "${FFMPEG_PID:-}" ] && kill "${FFMPEG_PID}" 2>/dev/null || true
    wait 2>/dev/null || true
}
trap cleanup TERM INT EXIT

WAIT_PIDS=()

echo "Starting Sendspin receiver..."
"${CMD[@]}" &
SENDSPIN_PID=$!
WAIT_PIDS+=("${SENDSPIN_PID}")

if [ "${FFMPEG_STREAM}" = "true" ]; then
    echo "Starting MP3 HTTP stream..."
    "${FFMPEG_CMD[@]}" &
    FFMPEG_PID=$!
    WAIT_PIDS+=("${FFMPEG_PID}")
fi

wait -n "${WAIT_PIDS[@]}"
EXIT_CODE=$?

echo "One process exited. Stopping..."
exit "${EXIT_CODE}"
