FROM bluenviron/mediamtx:latest-ffmpeg

RUN apk add --no-cache bash

EXPOSE 8554

COPY mediamtx.yml /mediamtx.yml
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
