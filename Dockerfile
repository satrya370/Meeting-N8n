FROM mwader/static-ffmpeg:6.0 AS ffmpeg

FROM n8nio/n8n:latest

USER root

COPY --from=ffmpeg /ffmpeg /usr/local/bin/ffmpeg
COPY --from=ffmpeg /ffprobe /usr/local/bin/ffprobe

USER node
