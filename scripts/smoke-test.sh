#!/usr/bin/env bash
#
# End-to-end check that the image really serves a playable RTSP stream.
# Used by CI and safe to run locally:  ./scripts/smoke-test.sh fake-rtsp:local
#
set -euo pipefail

IMAGE="${1:-fake-rtsp:local}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VIDEO="${VIDEO:-videos/parking.mp4}"

CONTAINERS=()

cleanup() {
  for c in "${CONTAINERS[@]:-}"; do
    [[ -n "$c" ]] && docker rm -f "$c" >/dev/null 2>&1 || true
  done
}
trap cleanup EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

wait_for_healthy() {
  local name="$1" state status
  for _ in $(seq 1 45); do
    state="$(docker inspect -f '{{.State.Status}}' "$name")"
    if [[ "$state" != "running" ]]; then
      docker logs "$name" || true
      fail "container $name stopped early (state: $state)"
    fi
    status="$(docker inspect -f '{{.State.Health.Status}}' "$name")"
    if [[ "$status" == "healthy" ]]; then
      return 0
    fi
    sleep 2
  done
  docker logs "$name" || true
  fail "container $name never became healthy"
}

# Probes the stream from outside the container, using the image's own ffprobe,
# so the test does not depend on ffmpeg being installed on the host or runner.
probe() {
  local url="$1"
  docker run --rm --network host --entrypoint ffprobe "$IMAGE" \
    -v error -rtsp_transport tcp -i "$url" \
    -show_entries stream=codec_name,width,height \
    -of default=noprint_wrappers=1
}

echo "==> Case 1: default port and stream name"
docker rm -f fake-rtsp-smoke-1 >/dev/null 2>&1 || true
CONTAINERS+=("fake-rtsp-smoke-1")
docker run -d --name fake-rtsp-smoke-1 \
  -p 8554:8554 \
  -v "${REPO_ROOT}/$(dirname "$VIDEO"):/videos:ro" \
  -e "VIDEO_PATH=/videos/$(basename "$VIDEO")" \
  -e STREAM_NAME=parking \
  "$IMAGE" >/dev/null
wait_for_healthy fake-rtsp-smoke-1
OUT="$(probe rtsp://127.0.0.1:8554/parking)"
echo "$OUT"
grep -q "codec_name=h264" <<<"$OUT" || fail "expected an h264 stream on the default port"

echo "==> Case 2: custom RTSP_PORT (regression check, the port used to be hardcoded)"
docker rm -f fake-rtsp-smoke-2 >/dev/null 2>&1 || true
CONTAINERS+=("fake-rtsp-smoke-2")
docker run -d --name fake-rtsp-smoke-2 \
  -p 9000:9000 \
  -v "${REPO_ROOT}/$(dirname "$VIDEO"):/videos:ro" \
  -e "VIDEO_PATH=/videos/$(basename "$VIDEO")" \
  -e RTSP_PORT=9000 \
  -e STREAM_NAME=warehouse \
  "$IMAGE" >/dev/null
wait_for_healthy fake-rtsp-smoke-2
OUT="$(probe rtsp://127.0.0.1:9000/warehouse)"
echo "$OUT"
grep -q "codec_name=h264" <<<"$OUT" || fail "expected an h264 stream on the custom port"

echo "==> Case 3: zero-argument run streams a generated test pattern"
docker rm -f fake-rtsp-smoke-3 >/dev/null 2>&1 || true
CONTAINERS+=("fake-rtsp-smoke-3")
docker run -d --name fake-rtsp-smoke-3 -p 8556:8554 "$IMAGE" >/dev/null
wait_for_healthy fake-rtsp-smoke-3
OUT="$(probe rtsp://127.0.0.1:8556/stream)"
echo "$OUT"
grep -q "codec_name=h264" <<<"$OUT" || fail "expected an h264 test pattern with no arguments"

echo "==> Case 4: missing video file fails fast with a clear message"
if docker run --rm -e VIDEO_PATH=/videos/does-not-exist.mp4 "$IMAGE" >/tmp/fake-rtsp-missing.log 2>&1; then
  fail "expected a non-zero exit code when the video file is missing"
fi
grep -q "Video file not found" /tmp/fake-rtsp-missing.log \
  || fail "expected a 'Video file not found' error message"
cat /tmp/fake-rtsp-missing.log

echo "==> Case 5: TEST_PATTERN=never disables the fallback"
if docker run --rm -e TEST_PATTERN=never "$IMAGE" >/tmp/fake-rtsp-never.log 2>&1; then
  fail "expected a non-zero exit code with TEST_PATTERN=never and no video mounted"
fi
grep -q "Video file not found" /tmp/fake-rtsp-never.log \
  || fail "expected a 'Video file not found' error message"

echo "==> Case 6: SIGTERM shuts the container down promptly"
START="$(date +%s)"
docker stop fake-rtsp-smoke-1 >/dev/null
ELAPSED=$(( $(date +%s) - START ))
[[ "$ELAPSED" -le 5 ]] || fail "shutdown took ${ELAPSED}s, expected a graceful stop under 5s"
echo "stopped in ${ELAPSED}s"

echo
echo "All smoke tests passed for $IMAGE"
