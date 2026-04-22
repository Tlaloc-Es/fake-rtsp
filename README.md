# 📷 fake-rtsp

> **No cameras. No hardware. No excuses.**
> Spin up a fleet of fake RTSP camera streams in seconds — perfect for NVRs, VMS, computer vision pipelines, and any RTSP-based app.

[![Docker Pulls](https://img.shields.io/docker/pulls/Tlaloc-Es/fake-rtsp?logo=docker&color=0db7ed)](https://hub.docker.com/r/Tlaloc-Es/fake-rtsp)
[![GitHub Stars](https://img.shields.io/github/stars/Tlaloc-Es/fake_rtsp?style=social)](https://github.com/Tlaloc-Es/fake-rtsp)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

```
rtsp://localhost:8554/stream  ←  your video, looping forever, live in 30 seconds
```

---

## The problem

You're building something that needs RTSP cameras — an NVR, a detection pipeline, a VMS, a reconnection test suite. You don't have physical cameras. You don't want to buy them. Setting up a real stream server is a rabbit hole.

**fake-rtsp solves this in one `docker run`.**

It takes any `.mp4` file and re-streams it as a live, looping RTSP feed using [mediamtx](https://github.com/bluenviron/mediamtx) + ffmpeg — zero config, zero hardware, zero headaches.

---

## Quickstart — 30 seconds to a live stream

```bash
docker run --rm \
  -p 8554:8554 \
  -v /path/to/your/videos:/videos:ro \
  -e VIDEO_PATH=/videos/my_clip.mp4 \
  ghcr.io/Tlaloc-Es/fake-rtsp
```

Your stream is live:

```
rtsp://localhost:8554/stream
```

```bash
ffplay rtsp://localhost:8554/stream   # or open in VLC
```

That's it. No YAML. No config files. No reading docs for 45 minutes.

---

## Simulate an entire camera fleet

Need 10 cameras? Run 10 containers. Each is completely independent — different port, different video, different stream name.

```yaml
# docker-compose.yml

services:

  camera-parking:
    build: .
    ports: ["8554:8554"]
    volumes: ["./videos:/videos:ro"]
    environment:
      VIDEO_PATH: /videos/parking.mp4
      STREAM_NAME: parking
    restart: unless-stopped

  camera-lobby:
    image: fake-rtsp
    ports: ["8555:8554"]
    volumes: ["./videos:/videos:ro"]
    environment:
      VIDEO_PATH: /videos/lobby.mp4
      STREAM_NAME: lobby
    restart: unless-stopped

  camera-entrance:
    image: fake-rtsp
    ports: ["8556:8554"]
    volumes: ["./videos:/videos:ro"]
    environment:
      VIDEO_PATH: /videos/entrance.mp4
      STREAM_NAME: entrance
    restart: unless-stopped
```

```bash
docker compose up --build
```

| Camera | URL |
|---|---|
| Parking | `rtsp://localhost:8554/parking` |
| Lobby | `rtsp://localhost:8555/lobby` |
| Entrance | `rtsp://localhost:8556/entrance` |

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

---

## Configuration

All options via environment variables — no files to edit.

| Variable | Default | Description |
|---|---|---|
| `VIDEO_PATH` | `/videos/video.mp4` | Path to the video inside the container |
| `STREAM_NAME` | `stream` | RTSP path: `rtsp://host:port/<name>` |
| `RTSP_PORT` | `8554` | Port mediamtx listens on |

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

**Health checks** — add this to any service to detect stream failures:
```yaml
healthcheck:
  test: ["CMD", "ffprobe", "rtsp://127.0.0.1:8554/stream"]
  interval: 30s
  timeout: 10s
  retries: 3
```

**Authentication** — mediamtx supports per-path credentials. Extend `mediamtx.yml` with username/password to test authenticated RTSP flows.

**Keep videos out of the image** — always mount via volume. Never bake video files into the Docker image — they'll bloat it and slow down every `docker pull`.

**Free test footage** — grab royalty-free `.mp4` clips from [Pexels](https://www.pexels.com/search/videos/street/) or [Pixabay](https://pixabay.com/videos/). No attribution required for most clips.

---

## Build from source

```bash
git clone https://github.com/Tlaloc-Es/fake-rtsp.git
cd fake_rtsp
docker build -t fake-rtsp .
docker run --rm \
  -p 8554:8554 \
  -v "$PWD/videos:/videos:ro" \
  -e VIDEO_PATH=/videos/parking.mp4 \
  fake-rtsp
```

---

## Contributing

PRs welcome. For large changes, open an issue first.

If fake-rtsp saved you from buying a camera or wiring up a real RTSP server, consider leaving a ⭐ — it helps others find the project.

---

## License

[MIT](LICENSE)