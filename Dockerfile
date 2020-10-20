ARG DOCKER_VERSION=19.03.8
ARG PYTHON_VERSION=3.7.7
ARG BUILD_ALPINE_VERSION=3.11
ARG BUILD_DEBIAN_VERSION=slim-stretch
ARG RUNTIME_ALPINE_VERSION=3.11.5
ARG RUNTIME_DEBIAN_VERSION=stretch-20200414-slim

ARG DISTRO=alpine

FROM docker:${DOCKER_VERSION} AS docker-cli

FROM python:${PYTHON_VERSION}-alpine${BUILD_ALPINE_VERSION} AS build-alpine
RUN apk add --no-cache \
    bash \
    build-base \
    ca-certificates \
    curl \
    gcc \
    git \
    libc-dev \
    libffi-dev \
    libgcc \
    make \
    musl-dev \
    openssl \
    openssl-dev \
    zlib-dev
ENV BUILD_BOOTLOADER=1

FROM python:${PYTHON_VERSION}-${BUILD_DEBIAN_VERSION} AS build-debian
RUN apt-get update && apt-get install --no-install-recommends -y \
    curl \
    gcc \
    git \
    libc-dev \
    libffi-dev \
    libgcc-6-dev \
    libssl-dev \
    make \
    openssl \
    zlib1g-dev

FROM build-${DISTRO} AS build
ENTRYPOINT ["sh", "/usr/local/bin/docker-compose-entrypoint.sh"]
WORKDIR /code/
COPY docker-compose-entrypoint.sh /usr/local/bin/
COPY --from=docker-cli /usr/local/bin/docker /usr/local/bin/docker
RUN pip install \
    virtualenv==20.0.30 \
    tox==3.19.0
COPY requirements-dev.txt .
COPY requirements-indirect.txt .
COPY requirements.txt .
RUN pip install -r requirements.txt -r requirements-indirect.txt -r requirements-dev.txt
COPY .pre-commit-config.yaml .
COPY tox.ini .
COPY setup.py .
COPY README.md .
COPY compose compose/
RUN tox --notest
COPY . .
ARG GIT_COMMIT=unknown
ENV DOCKER_COMPOSE_GITSHA=$GIT_COMMIT
RUN script/build/linux-entrypoint

FROM scratch AS bin
ARG TARGETARCH
ARG TARGETOS
COPY --from=build /usr/local/bin/docker-compose /docker-compose-${TARGETOS}-${TARGETARCH}

FROM alpine:${RUNTIME_ALPINE_VERSION} AS runtime-alpine
FROM debian:${RUNTIME_DEBIAN_VERSION} AS runtime-debian
FROM runtime-${DISTRO} AS runtime
COPY docker-compose-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["sh", "/usr/local/bin/docker-compose-entrypoint.sh"]
COPY --from=docker-cli  /usr/local/bin/docker           /usr/local/bin/docker
COPY --from=build       /usr/local/bin/docker-compose   /usr/local/bin/docker-compose
