FROM python:3.12-slim

ARG SENDSPIN_DOCKER_VERSION=dev

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libportaudio2 \
        alsa-utils \
        bash \
        ca-certificates \
        ffmpeg \
        procps \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir sendspin

RUN useradd -r -u 1000 -m -d /home/sendspin sendspin

ENV SENDSPIN_NAME="Sendspin Speaker"
ENV SENDSPIN_AUDIO_DEVICE=""
ENV SENDSPIN_SERVER_URL=""
ENV SENDSPIN_AUDIO_FORMAT=""
ENV SENDSPIN_STATIC_DELAY_MS=""
ENV SENDSPIN_LOG_LEVEL="INFO"
ENV SENDSPIN_PORT="8927"
ENV SENDSPIN_HOOK_START=""
ENV SENDSPIN_HOOK_STOP=""
ENV SENDSPIN_HOOK_SET_VOLUME=""
ENV SENDSPIN_HARDWARE_VOLUME="true"
ENV SENDSPIN_CLIENT_ID=""
ENV SENDSPIN_MANUFACTURER=""
ENV SENDSPIN_PRODUCT_NAME=""
ENV SENDSPIN_DOCKER_VERSION="${SENDSPIN_DOCKER_VERSION}"

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER sendspin

ENTRYPOINT ["/entrypoint.sh"]
