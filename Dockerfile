FROM bluenviron/mediamtx:latest-ffmpeg

LABEL org.opencontainers.image.title="fake-rtsp" \
      org.opencontainers.image.description="Turn any video file into a live, looping RTSP camera stream" \
      org.opencontainers.image.source="https://github.com/Tlaloc-Es/fake-rtsp" \
      org.opencontainers.image.documentation="https://github.com/Tlaloc-Es/fake-rtsp#readme" \
      org.opencontainers.image.licenses="MIT"

# bash: the entrypoint needs [[ ]], /dev/tcp and `wait -n`.
# font-dejavu: the generated test pattern burns a clock in with drawtext.
# Not version-pinned on purpose: the pin would break every base image refresh.
# hadolint ignore=DL3018
RUN apk add --no-cache bash font-dejavu

ENV VIDEO_PATH=/videos/video.mp4 \
    STREAM_NAME=stream \
    RTSP_PORT=8554 \
    TEST_PATTERN=auto \
    TEST_PATTERN_SIZE=1280x720 \
    TEST_PATTERN_FPS=25

EXPOSE 8554

COPY mediamtx.yml /mediamtx.yml
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Shell form via /bin/sh -c so RTSP_PORT and STREAM_NAME expand at runtime
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
  CMD ["/bin/sh", "-c", "ffprobe -v error -rtsp_transport tcp -i \"rtsp://127.0.0.1:${RTSP_PORT}/${STREAM_NAME}\" -show_entries format=format_name -of csv=p=0 || exit 1"]

ENTRYPOINT ["/entrypoint.sh"]
