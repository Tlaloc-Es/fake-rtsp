# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-08-03

First tagged release, and the first one with a published container image.

### Added

- Container images published to `ghcr.io/tlaloc-es/fake-rtsp` for `linux/amd64`,
  `linux/arm64` and `linux/arm/v7`, with build provenance attestation.
- Zero-argument mode: with no video mounted, the container streams a generated
  720p test pattern with a burnt-in clock, so `docker run -p 8554:8554 ghcr.io/tlaloc-es/fake-rtsp`
  is enough to get a live stream. Controlled by `TEST_PATTERN`,
  `TEST_PATTERN_SIZE` and `TEST_PATTERN_FPS`.
- `HEALTHCHECK` in the image, so `docker ps`, Compose and CI service containers
  can tell when a stream stops serving.
- `scripts/smoke-test.sh`, an end-to-end check that starts the image and asserts
  a real client can read the stream. Run in CI on every pull request and before
  every publish.
- CI workflow running ShellCheck, hadolint, `docker compose config` and the smoke
  test.
- OCI image labels linking the image back to this repository.
- `.dockerignore`, keeping videos and documentation assets out of the build
  context.

### Fixed

- `RTSP_PORT` had no effect: `mediamtx.yml` hardcoded port 8554, so any value
  other than the default left ffmpeg pushing to a port nothing was listening on
  and the container exited immediately. The port is now applied through
  `MTX_RTSPADDRESS`.
- The startup race between mediamtx and ffmpeg is now resolved by waiting for the
  port to accept connections instead of sleeping for a fixed second.
- `SIGTERM` now stops both processes, so `docker stop` returns immediately
  instead of waiting for the kill timeout.
- If either mediamtx or ffmpeg dies, the container now exits so the restart
  policy can recreate it, instead of lingering with a dead stream.
- Quickstart in the README referenced an image that was never published, under a
  reference Docker rejects for having uppercase characters.
- `docker-compose.yml` mixed `build: .` with `image: fake-rtsp`, so the second
  and third services could not start without building first. All services now
  use the published image.
- README: stars badge pointed at a non-existent repository name, the Docker Hub
  pulls badge rendered as "invalid", and `Build from source` cloned `fake-rtsp`
  then changed into `fake_rtsp`.

[1.0.0]: https://github.com/Tlaloc-Es/fake-rtsp/releases/tag/v1.0.0
