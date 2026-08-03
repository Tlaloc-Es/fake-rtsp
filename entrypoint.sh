#!/bin/bash
set -euo pipefail

# The value baked into the Dockerfile. Used to tell "the user did not pick a
# video" apart from "the user picked a video and it is missing".
readonly DEFAULT_VIDEO_PATH="/videos/video.mp4"
readonly FONT="/usr/share/fonts/dejavu/DejaVuSansMono.ttf"

VIDEO_PATH="${VIDEO_PATH:-$DEFAULT_VIDEO_PATH}"
STREAM_NAME="${STREAM_NAME:-stream}"
RTSP_PORT="${RTSP_PORT:-8554}"
TEST_PATTERN="${TEST_PATTERN:-auto}"
TEST_PATTERN_SIZE="${TEST_PATTERN_SIZE:-1280x720}"
TEST_PATTERN_FPS="${TEST_PATTERN_FPS:-25}"

case "$TEST_PATTERN" in
  auto | always | never) ;;
  *)
    echo "[fake-rtsp] ERROR: TEST_PATTERN must be auto, always or never (got: ${TEST_PATTERN})" >&2
    exit 1
    ;;
esac

# Decide between re-streaming a file and generating a synthetic pattern
USE_TEST_PATTERN=false
if [[ "$TEST_PATTERN" == "always" ]]; then
  USE_TEST_PATTERN=true
elif [[ ! -f "$VIDEO_PATH" ]]; then
  if [[ "$TEST_PATTERN" == "auto" && "$VIDEO_PATH" == "$DEFAULT_VIDEO_PATH" ]]; then
    # Nothing was mounted and no video was requested: stream a test pattern so
    # the container is useful with no arguments at all.
    USE_TEST_PATTERN=true
  else
    echo "[fake-rtsp] ERROR: Video file not found: $VIDEO_PATH" >&2
    echo "[fake-rtsp] Mount a video file and set VIDEO_PATH accordingly," >&2
    echo "[fake-rtsp] or set TEST_PATTERN=always to stream a generated pattern instead." >&2
    exit 1
  fi
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

RTSP_URL="rtsp://127.0.0.1:${RTSP_PORT}/${STREAM_NAME}"

if [[ "$USE_TEST_PATTERN" == true ]]; then
  echo "[fake-rtsp] Streaming a generated ${TEST_PATTERN_SIZE}@${TEST_PATTERN_FPS}fps test pattern"
  echo "[fake-rtsp] → rtsp://0.0.0.0:${RTSP_PORT}/${STREAM_NAME}"

  # A burnt-in clock makes the stream obviously live and lets you eyeball latency
  OVERLAY="drawtext=fontfile=${FONT}:text='fake-rtsp %{localtime\\:%X}'"
  OVERLAY+=":x=32:y=32:fontsize=44:fontcolor=white:box=1:boxcolor=black@0.5:boxborderw=12"

  ffmpeg \
    -loglevel warning \
    -re \
    -f lavfi -i "testsrc2=size=${TEST_PATTERN_SIZE}:rate=${TEST_PATTERN_FPS}" \
    -vf "$OVERLAY" \
    -c:v libx264 -preset veryfast -tune zerolatency \
    -pix_fmt yuv420p -g "$(( TEST_PATTERN_FPS * 2 ))" \
    -f rtsp \
    "$RTSP_URL" &
else
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
    "$RTSP_URL" &
fi
FFMPEG_PID=$!

# Exit as soon as either process dies, so the container restart policy can react
set +e
wait -n "$MEDIAMTX_PID" "$FFMPEG_PID"
STATUS=$?
echo "[fake-rtsp] A process exited with status ${STATUS}, stopping the container..."
kill "$FFMPEG_PID" "$MEDIAMTX_PID" 2>/dev/null
exit "$STATUS"
