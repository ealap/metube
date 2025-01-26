FROM node:alpine AS builder

ENV WORK_DIR="/metube"

WORKDIR "${WORK_DIR}"

COPY "ui" "${WORK_DIR}"

RUN npm ci \
	&& "node_modules/.bin/ng" build --configuration "production"

FROM ghcr.io/astral-sh/uv:python3.13-alpine

ENV WORK_DIR="/app"

ENV UV_COMPILE_BYTECODE="1"

ENV UV_LINK_MODE="copy"

WORKDIR "${WORK_DIR}"

COPY "pyproject.toml" "docker-entrypoint.sh" "${WORK_DIR}"

RUN sed -i 's/\r$//g' "docker-entrypoint.sh" \
	&& chmod +x "docker-entrypoint.sh"

RUN apk upgrade \
	&& apk add --update "aria2" "coreutils" "curl" "ffmpeg" "shadow" "su-exec" "tini" \
	&& apk add --update --virtual ".build-deps" "gcc" "g++" "musl-dev" \
	&& apk del ".build-deps" \
	&& rm -rf "/var/cache/apk/"* \
    && mkdir "/.cache" && chmod 777 "/.cache"

RUN uv sync

COPY "app" "${WORK_DIR}/app"
COPY --from="builder" "/metube/dist/metube" "${WORK_DIR}/ui/dist/metube"

ENV UID="1000"
ENV GID="1000"
ENV UMASK="022"

ENV DOWNLOAD_DIR="/downloads"
ENV STATE_DIR="/downloads/.metube"
ENV TEMP_DIR="/downloads"
VOLUME "/downloads"

EXPOSE 8081
ENTRYPOINT ["/sbin/tini", "-g", "--", "./docker-entrypoint.sh"]
