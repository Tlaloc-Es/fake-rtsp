# 📷 fake-rtsp

> **No cameras. No hardware. No excuses.**
> Spin up a fleet of fake RTSP camera streams in seconds — perfect for NVRs, VMS, computer vision pipelines, and any RTSP-based app.

[![Publish Docker image](https://github.com/Tlaloc-Es/fake-rtsp/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/Tlaloc-Es/fake-rtsp/actions/workflows/docker-publish.yml)
[![Release](https://img.shields.io/github/v/release/Tlaloc-Es/fake-rtsp?logo=github)](https://github.com/Tlaloc-Es/fake-rtsp/releases)
[![Container image](https://img.shields.io/badge/ghcr.io-fake--rtsp-0db7ed?logo=docker&logoColor=white)](https://github.com/Tlaloc-Es/fake-rtsp/pkgs/container/fake-rtsp)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![GitHub Stars](https://img.shields.io/github/stars/Tlaloc-Es/fake-rtsp?style=social)](https://github.com/Tlaloc-Es/fake-rtsp)

---
![fake-rtsp-logo](https://raw.githubusercontent.com/Tlaloc-Es/fake-rtsp/master/logo.webp)
---

```
rtsp://localhost:8554/stream  ←  your video, looping forever, live in 30 seconds
```

![fake-rtsp re-streaming a looping video file over RTSP](https://raw.githubusercontent.com/Tlaloc-Es/fake-rtsp/master/docs/demo.webp)

---

## Quickstart

No video, no volume, no flags — this alone gives you a live RTSP camera:

```bash
docker run --rm -p 8554:8554 ghcr.io/tlaloc-es/fake-rtsp
```

```bash
ffplay rtsp://localhost:8554/stream   # or open it in VLC
```

You get a generated 720p test pattern with a burnt-in clock, so you can see at a
glance that the stream is live and eyeball the latency.

**Now with your own footage:**

```bash
docker run --rm \
  -p 8554:8554 \
  -v /path/to/your/videos:/videos:ro \
  -e VIDEO_PATH=/videos/my_clip.mp4 \
  ghcr.io/tlaloc-es/fake-rtsp
```

That's it. No YAML. No config files. No reading docs for 45 minutes.

Images are published for `linux/amd64`, `linux/arm64` and `linux/arm/v7`, so the
same command works on a laptop, a server, or a Raspberry Pi.

---

## The problem

You're building something that needs RTSP cameras — an NVR, a detection pipeline, a VMS, a reconnection test suite. You don't have physical cameras. You don't want to buy them. Setting up a real stream server is a rabbit hole.

**fake-rtsp solves this in one `docker run`.**

It takes any `.mp4` file and re-streams it as a live, looping RTSP feed using [mediamtx](https://github.com/bluenviron/mediamtx) + ffmpeg — zero config, zero hardware, zero headaches.

---

## Simulate an entire camera fleet

Need 10 cameras? Run 10 containers. Each is completely independent — different port, different video, different stream name.

The [`docker-compose.yml`](docker-compose.yml) in this repo runs as-is:

```yaml
services:

  camera-parking:
    image: ghcr.io/tlaloc-es/fake-rtsp:latest
    ports: ["8554:8554"]
    volumes: ["./videos:/videos:ro"]
    environment:
      VIDEO_PATH: /videos/parking.mp4
      STREAM_NAME: parking
    restart: unless-stopped

  camera-entrance:
    image: ghcr.io/tlaloc-es/fake-rtsp:latest
    ports: ["8555:8554"]
    volumes: ["./videos:/videos:ro"]
    environment:
      VIDEO_PATH: /videos/entrance.mp4
      STREAM_NAME: entrance
    restart: unless-stopped
```

```bash
docker compose up
```

| Camera | URL |
|---|---|
| Parking | `rtsp://localhost:8554/parking` |
| Entrance | `rtsp://localhost:8555/entrance` |

Add another camera by copying a block: bump the host port, point `VIDEO_PATH` at
another file, and give it its own `STREAM_NAME`.

---

## Use it in CI

This is where the zero-argument mode pays off. CI service containers start
*before* your repository is checked out, so there is no video file to mount yet —
the generated test pattern needs none.

**GitHub Actions**

```yaml
jobs:
  integration:
    runs-on: ubuntu-latest
    services:
      camera:
        image: ghcr.io/tlaloc-es/fake-rtsp:1
        ports:
          - 8554:8554
    steps:
      - uses: actions/checkout@v4
      - run: pytest tests/    # a real RTSP source at rtsp://127.0.0.1:8554/stream
```

The image ships a `HEALTHCHECK`, so the runner waits until the stream is actually
serving before your steps start.

**GitLab CI**

```yaml
integration-tests:
  image: python:3.12
  services:
    - name: ghcr.io/tlaloc-es/fake-rtsp:1
      alias: camera
  script:
    - pytest tests/           # rtsp://camera:8554/stream
```

Pin to a major tag (`:1`) to get fixes without surprise breaking changes.

---

## How it works

```
┌──────────────────────────────────────────────────────────┐
│                      Docker host                         │
│                                                          │
│  ./videos/parking.mp4  ──►  ffmpeg  ──►  mediamtx :8554 │
│  ./videos/lobby.mp4    ──►  ffmpeg  ──►  mediamtx :8555 │
│  ./videos/entrance.mp4 ──►  ffmpeg  ──►  mediamtx :8556 │
│                                                          │
└───────────────┬──────────────────┬──────────────┬────────┘
                ▼                  ▼              ▼
          VLC / ffplay       NVR client     Your app
```

- **ffmpeg** reads the video file and loops it indefinitely with `-stream_loop -1`
- **mediamtx** acts as a lightweight RTSP server, no config needed
- **`-c copy`** passes through the original codec — no re-encoding, no quality loss, minimal CPU
- with nothing mounted, ffmpeg generates the frames from `testsrc2` instead

Both processes live in one container. If either dies the container exits, so
`restart: unless-stopped` brings the camera back on its own.

---

## Configuration

All options via environment variables — no files to edit.

| Variable | Default | Description |
|---|---|---|
| `VIDEO_PATH` | `/videos/video.mp4` | Path to the video inside the container |
| `STREAM_NAME` | `stream` | RTSP path: `rtsp://host:port/<name>` |
| `RTSP_PORT` | `8554` | Port mediamtx listens on |
| `TEST_PATTERN` | `auto` | `auto` falls back to a generated pattern when nothing is mounted, `always` forces it, `never` fails instead |
| `TEST_PATTERN_SIZE` | `1280x720` | Resolution of the generated pattern |
| `TEST_PATTERN_FPS` | `25` | Frame rate of the generated pattern |

Pointing `VIDEO_PATH` at a file that does not exist is always an error — the
fallback only applies when you did not ask for a specific video.

---

## Use cases

**NVR & VMS development** — feed deterministic footage into your recorder without owning a single camera. Test recording schedules, motion detection triggers, and retention policies.

**Computer vision pipelines** — replay the same clip on loop to get reproducible results while iterating on your detection or tracking model. No flaky hardware, no lighting changes.

**CI/CD integration tests** — use fake-rtsp as a service in GitHub Actions or GitLab CI to provide a real RTSP source for end-to-end tests. Reproducible and containerised.

**RTSP client development** — test reconnection logic, timeout handling, codec compatibility, and authentication flows against a predictable stream.

**Load testing** — spin up dozens of streams on a single machine to benchmark your ingest pipeline under load.

---

## Tips & tricks

**Codec compatibility** — use H.264/AAC sources for maximum client compatibility. The container streams whatever codec is in the source file with `-c copy`, so pre-encode if needed.

**Health checks** — the image already defines one, so `docker ps` and your orchestrator know when a stream is down. Override it only if you want different timings:

```yaml
healthcheck:
  test: ["CMD", "ffprobe", "-v", "error", "-rtsp_transport", "tcp",
         "-i", "rtsp://127.0.0.1:8554/parking",
         "-show_entries", "format=format_name", "-of", "csv=p=0"]
  interval: 30s
  timeout: 10s
  retries: 3
```

**Authentication** — mediamtx supports per-path credentials. Extend `mediamtx.yml` with username/password to test authenticated RTSP flows.

**Keep videos out of the image** — always mount via volume. Never bake video files into the Docker image — they'll bloat it and slow down every `docker pull`.

**Free test footage** — grab royalty-free `.mp4` clips from [Pexels](https://www.pexels.com/search/videos/street/) or [Pixabay](https://pixabay.com/videos/). No attribution required for most clips.

---

## How it compares

The closest alternatives are compose recipes: you clone the repository, edit
`docker-compose.yml`, and run a separate ffmpeg container per stream next to a
shared RTSP server. fake-rtsp packages the whole thing as a single image instead.

| | fake-rtsp | [Fake-RTSP-Stream](https://github.com/insight-platform/Fake-RTSP-Stream) | [Dummy-RTSP](https://github.com/charkaoui007/Dummy-RTSP) |
|---|---|---|---|
| Ready-to-run published image | ✅ `ghcr.io/tlaloc-es/fake-rtsp` | ❌ clone the repo | ❌ clone the repo |
| Runs with no configuration | ✅ generated test pattern | ❌ | ❌ |
| Containers per camera | 1 | 2 (RTSP server + ffmpeg) | 2 |
| Configuration surface | environment variables | edit `docker-compose.yml` | edit `docker-compose.yml` |
| Built-in container healthcheck | ✅ | ❌ | ❌ |
| Concatenate several files into one stream | ❌ ([#5](https://github.com/Tlaloc-Es/fake-rtsp/issues/5)) | ✅ | ✅ |

If you need the concatenation behaviour today, those projects do it and fake-rtsp
does not yet.

---

## Roadmap

- [ONVIF device emulation](https://github.com/Tlaloc-Es/fake-rtsp/issues/1) (WS-Discovery + media profiles), so an NVR discovers the stream like real hardware
- [Fault injection](https://github.com/Tlaloc-Es/fake-rtsp/issues/2): drop the stream, stall it, add jitter, so clients can be tested against failures
- [RTSP authentication](https://github.com/Tlaloc-Es/fake-rtsp/issues/3) exposed as environment variables
- [Several streams from one container](https://github.com/Tlaloc-Es/fake-rtsp/issues/4), instead of one container per camera
- [Concatenating several files](https://github.com/Tlaloc-Es/fake-rtsp/issues/5) into a single continuous stream

Ideas and pull requests welcome — there are [good first issues](https://github.com/Tlaloc-Es/fake-rtsp/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22) open too.

---

## Build from source

```bash
git clone https://github.com/Tlaloc-Es/fake-rtsp.git
cd fake-rtsp
docker build -t fake-rtsp .
docker run --rm \
  -p 8554:8554 \
  -v "$PWD/videos:/videos:ro" \
  -e VIDEO_PATH=/videos/parking.mp4 \
  fake-rtsp
```

Check a build end to end with the same script CI runs:

```bash
./scripts/smoke-test.sh fake-rtsp
```

It starts the image and asserts that a real client can read the stream, on the
default port and on a custom one, that a missing video fails loudly, and that the
container stops gracefully.

---

## Contributing

PRs welcome. For large changes, open an issue first.

Please run `./scripts/smoke-test.sh` before pushing.

If fake-rtsp saved you from buying a camera or wiring up a real RTSP server, consider leaving a ⭐ — it helps others find the project.

---

## License

[MIT](LICENSE)
