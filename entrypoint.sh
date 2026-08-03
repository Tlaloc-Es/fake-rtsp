#!/bin/bash
set -euo pipefail

VIDEO_PATH="${VIDEO_PATH:-/videos/video.mp4}"
STREAM_NAME="${STREAM_NAME:-stream}"
RTSP_PORT="${RTSP_PORT:-8554}"

# Validate video file exists
if [[ ! -f "$VIDEO_PATH" ]]; then
  echo "[fake-rtsp] ERROR: Video file not found: $VIDEO_PATH" >&2
  echo "[fake-rtsp] Mount a video file and set VIDEO_PATH accordingly." >&2
  exit 1
fi

echo "[fake-rtsp] Starting mediamtx on port ${RTSP_PORT}..."

# mediamtx reads MTX_* variables and they take precedence over mediamtx.yml.
# This is what makes RTSP_PORT actually move the listening port.
export MTX_RTSPADDRESS=":${RTSP_PORT}"

/mediamtx /mediamtx.yml &
MEDIAMTX_PID=$!
FFMPEG_PID=""

# Clean shutdown on SIGTERM/SIGINT
# shellcheck disable=SC2317,SC2329  # invoked through trap
cleanup() {
  echo "[fake-rtsp] Shutting down..."
  if [[ -n "$FFMPEG_PID" ]]; then
    kill "$FFMPEG_PID" 2>/dev/null || true
  fi
  kill "$MEDIAMTX_PID" 2>/dev/null || true
  exit 0
}
trap cleanup SIGTERM SIGINT

# Wait for mediamtx to accept connections instead of guessing with a fixed sleep
for _ in $(seq 1 100); do
  if (exec 3<>"/dev/tcp/127.0.0.1/${RTSP_PORT}") 2>/dev/null; then
    break
  fi
  sleep 0.1
done

echo "[fake-rtsp] Streaming '${VIDEO_PATH}' → rtsp://0.0.0.0:${RTSP_PORT}/${STREAM_NAME}"

# Loop the video indefinitely and push it to mediamtx via RTSP.
# -c copy passes the original codec through: no re-encode, no quality loss.
ffmpeg \
  -loglevel warning \
  -re \
  -stream_loop -1 \
  -i "$VIDEO_PATH" \
  -c copy \
  -f rtsp \
  "rtsp://127.0.0.1:${RTSP_PORT}/${STREAM_NAME}" &
FFMPEG_PID=$!

# Exit as soon as either process dies, so the container restart policy can react
set +e
wait -n "$MEDIAMTX_PID" "$FFMPEG_PID"
STATUS=$?
echo "[fake-rtsp] A process exited with status ${STATUS}, stopping the container..."
kill "$FFMPEG_PID" "$MEDIAMTX_PID" 2>/dev/null
exit "$STATUS"
