ARG BUILD_FROM=ghcr.io/home-assistant/base:latest
FROM ${BUILD_FROM}

RUN apk add --no-cache \
    bash \
    curl \
    docker-cli \
    docker-cli-compose \
    git \
    jq \
    openssl

COPY run.sh /run.sh
RUN chmod 0755 /run.sh

CMD ["/run.sh"]
