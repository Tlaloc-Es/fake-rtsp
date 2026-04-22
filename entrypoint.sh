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
/mediamtx /mediamtx.yml &
MEDIAMTX_PID=$!

# Clean shutdown on SIGTERM/SIGINT
cleanup() {
  echo "[fake-rtsp] Shutting down..."
  kill "$MEDIAMTX_PID" 2>/dev/null || true
  exit 0
}
trap cleanup SIGTERM SIGINT

# Wait for mediamtx to be ready
sleep 1

echo "[fake-rtsp] Streaming '${VIDEO_PATH}' → rtsp://0.0.0.0:${RTSP_PORT}/${STREAM_NAME}"

# Loop the video indefinitely and push it to mediamtx via RTSP
exec ffmpeg \
  -loglevel warning \
  -re \
  -stream_loop -1 \
  -i "$VIDEO_PATH" \
  -c copy \
  -f rtsp \
  "rtsp://127.0.0.1:${RTSP_PORT}/${STREAM_NAME}"
