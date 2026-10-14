# syntax=docker/dockerfile:1.7
#
# RCAAP-branded Anubis. Fetches upstream source at a pinned tag, overlays
# ./overlay (index.templ + mascot images) and builds a minimal static image.
#
#   docker build -t <user>/anubis-rcaap:1.28.1 .

ARG ANUBIS_VERSION=1.28.1
ARG GO_VERSION=1.26
ARG NODE_VERSION=22

FROM node:${NODE_VERSION}-bookworm-slim AS node

FROM golang:${GO_VERSION}-bookworm AS build
ARG ANUBIS_VERSION
ARG TARGETOS
ARG TARGETARCH

RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates gcc libc6-dev zstd brotli gzip \
 && rm -rf /var/lib/apt/lists/*

COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
 && ln -s ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx

ENV RUSTUP_HOME=/usr/local/rustup CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:/src/node_modules/.bin:$PATH
RUN curl -fsSL https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain stable \
 && rustup target add wasm32-unknown-unknown

WORKDIR /src
ADD https://github.com/TecharoHQ/anubis/archive/refs/tags/v${ANUBIS_VERSION}.tar.gz /tmp/anubis.tar.gz
RUN tar -xzf /tmp/anubis.tar.gz --strip-components=1 && rm /tmp/anubis.tar.gz

RUN npm ci --no-audit --no-fund

# Replace upstream template and mascot images.
COPY overlay/ /src/

# esbuild/postcss come from node_modules/.bin; wasm-opt falls back to the bundled wazero runner.
RUN npm run assets

RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
    go build -trimpath -ldflags '-s -w -extldflags "-static"' -o /out/anubis ./cmd/anubis

FROM cgr.dev/chainguard/static:latest
COPY --from=build /out/anubis /ko-app/anubis
USER 1000
ENTRYPOINT ["/ko-app/anubis"]
