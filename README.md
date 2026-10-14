# rcaap-anubis-theme

RCAAP-branded build of [Anubis](https://github.com/TecharoHQ/anubis), the web AI firewall.

Instead of forking Anubis, this repository holds a small **overlay** and a multi-stage `Dockerfile`. At build time the Dockerfile downloads a pinned upstream release, copies the overlay over the upstream sources, builds Anubis, and produces a minimal static image (same base as the official one: `cgr.dev/chainguard/static`, single binary, non-root user).

## Repository layout

```text
Dockerfile                              Multi-stage build (upstream source + overlay -> minimal image)
.dockerignore                           Restricts the build context to ./overlay
overlay/web/index.templ                 Replaces upstream web/index.templ (page layout and RCAAP intro text)
overlay/web/static/img/happy.webp       Replaces the upstream mascot images
overlay/web/static/img/pensive.webp
overlay/web/static/img/reject.webp
.github/workflows/docker-build.yml      CI check that the image builds
```

Every file under `overlay/` is copied onto the upstream source tree at the same relative path, so any other upstream file can be customised by adding it to the overlay.

## Customising

1. **Images**: replace the three `.webp` files in `overlay/web/static/img/`. Keep the file names: upstream templates and `web/js/main.ts` reference them by name (`pensive` = solving the challenge, `happy` = success, `reject` = error).
2. **Text and layout**: edit `overlay/web/index.templ` ([templ](https://templ.guide) syntax; presentation only).
3. Build and check the result locally (see below).

> `overlay/web/index.templ` is a copy of the upstream file for the pinned version. When bumping `ANUBIS_VERSION`, diff it against the upstream file of the new tag and port your changes.

## Building

Requirements: Docker with BuildKit (default in current Docker releases).

```shell
docker build -t <user>/anubis-rcaap:1.28.1 .
```

Build arguments:

| Argument         | Default  | Description                          |
| ---------------- | -------- | ------------------------------------ |
| `ANUBIS_VERSION` | `1.28.1` | Upstream Anubis release tag (no `v`) |
| `GO_VERSION`     | `1.26`   | Go toolchain image tag               |
| `NODE_VERSION`   | `22`     | Node.js image tag                    |

The first build is slow (Rust/wasm and JS assets are built from source); later builds reuse Docker's layer cache.

Multi-architecture build and push:

```shell
docker buildx build --platform linux/amd64,linux/arm64 \
  -t <user>/anubis-rcaap:1.28.1 --push .
```

## Running

The image has the same entrypoint and configuration as upstream Anubis (environment variables such as `TARGET`, `BIND`, `DIFFICULTY`, `ED25519_PRIVATE_KEY_HEX`, `POLICY_FNAME`). See the [upstream documentation](https://anubis.techaro.lol/docs/).

```shell
docker run --rm -p 8923:8923 \
  -e TARGET=http://host.docker.internal:3000 \
  -e ED25519_PRIVATE_KEY_HEX=$(openssl rand -hex 32) \
  <user>/anubis-rcaap:1.28.1
```

## Publishing to Docker Hub

```shell
docker login
docker push <user>/anubis-rcaap:1.28.1
```

## Continuous integration

`.github/workflows/docker-build.yml` builds the image on every pull request and push to `main` that touches the build inputs, then runs a smoke test: the container is started and must serve the overlay mascot image and the customised challenge page. Nothing is pushed.

## License

See [LICENSE](LICENSE). Upstream Anubis is MIT-licensed; its license and attributions apply to the upstream code downloaded at build time.
