# Containerizing a Go Service

Packaging the binary into a small, secure, reproducible image. This is build-craft — the Dockerfile for *your app*. Orchestration (compose, k8s, proxies) is out of scope. Starters: [`../../assets/Dockerfile`](../../assets/Dockerfile) and [`../../assets/.dockerignore`](../../assets/.dockerignore).

## Multi-Stage: Build Fat, Ship Thin
Compile in a full toolchain image, then copy only the binary into a minimal runtime. The final image carries no compiler, no source, no module cache.
```dockerfile
# ---- build ----
FROM golang:1.23 AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w -X main.version=${VERSION}" -o /out/app ./cmd/app

# ---- run ----
FROM gcr.io/distroless/static:nonroot
COPY --from=build /out/app /app
USER nonroot:nonroot
ENTRYPOINT ["/app"]
```

## Cache Dependencies in Their Own Layer
Copy `go.mod`/`go.sum` and run `go mod download` **before** copying the source. A code-only change then doesn't re-download the world — the deps layer stays cached.
- **Reason:** Docker caches layers by content; putting volatile inputs (source) after stable ones (deps) maximizes cache hits.

For repeated local/CI builds, use BuildKit cache mounts so the module and build caches persist across builds:
```dockerfile
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/app ./cmd/app
```

## Build a Static, Reproducible Binary
- **`CGO_ENABLED=0`** — pure-Go static binary; runs on `scratch`/`distroless` with no libc. Set it explicitly; the default depends on whether a C toolchain is present.
- **`-trimpath`** — strip local filesystem paths from the binary for reproducibility and to avoid leaking build-host paths.
- **`-ldflags="-s -w"`** — drop the symbol table and DWARF debug info for a smaller binary. Omit if you need symbols for production profiling.
- **`GOOS`/`GOARCH`** — set for cross-compiles (e.g. building `linux/amd64` on an arm64 Mac).

## Embed the Version with `-ldflags -X`
Inject build metadata at link time into a package variable; expose it via a `/version` endpoint or a build-info metric.
```go
// cmd/app/main.go
var version = "dev" // overridden by -ldflags -X main.version=...
```
```dockerfile
ARG VERSION=dev
RUN CGO_ENABLED=0 go build -ldflags="-s -w -X main.version=${VERSION}" -o /out/app ./cmd/app
```
Pass the real value at build time: `--build-arg VERSION=$(git describe --tags --always)`. **Never** bake secrets into `ARG`/`ENV` — they persist in image history.

## Pick a Minimal Base
| Base | Has | Use when |
|---|---|---|
| `gcr.io/distroless/static:nonroot` | CA certs, tzdata, `/etc/passwd`, **no shell** | default for static Go binaries |
| `scratch` | nothing | absolute minimum; you supply CA certs yourself |
| `alpine` | shell, apk, libc | you need a shell / dynamic deps (accept CGO + larger surface) |

For `scratch`, copy what you need from the builder:
```dockerfile
FROM scratch
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=build /out/app /app
ENTRYPOINT ["/app"]
```

## Run as Non-Root
Never run the process as root. `distroless:nonroot` ships a `nonroot` user (uid 65532); set `USER`. On `scratch`, run with a numeric uid (`USER 65532:65532`) so it works under read-only root filesystems and restricted runtimes.

## Pin the Base by Digest
Tags move; digests don't. Pin for reproducible, tamper-evident builds:
```dockerfile
FROM golang:1.23@sha256:... AS build
```
Bump digests deliberately (Renovate/Dependabot) — the same discipline as `go.mod` pinning ([`modules.md`](./modules.md)).

## Healthcheck Nuance
`distroless`/`scratch` have **no shell**, so `HEALTHCHECK CMD curl ...` won't work. Options:
- Rely on the orchestrator's liveness/readiness probes (preferred — see [`../recipes/health-checks.md`](../recipes/health-checks.md)).
- Or give the binary a self-check subcommand and use exec form: `HEALTHCHECK CMD ["/app", "healthcheck"]`.

## `.dockerignore`
Keep the build context small and avoid cache-busting on irrelevant changes. Exclude `bin/`, `.git/`, test artifacts, and local env files. See the starter.
- **Reason:** The whole context is uploaded to the daemon every build; a bloated context is slow and can invalidate the `COPY . .` layer on unrelated edits.

## Multi-Arch (brief)
Build for several platforms with buildx, letting Go cross-compile via `GOOS`/`GOARCH` (cheap) rather than QEMU-emulating the whole build (slow):
```bash
docker buildx build --platform linux/amd64,linux/arm64 -t app:1.2.3 --push .
```

## Checklist
- [ ] Multi-stage: toolchain in build, only the binary in the final image.
- [ ] `go mod download` in its own cached layer before `COPY . .`.
- [ ] `CGO_ENABLED=0` + `-trimpath` + `-ldflags="-s -w"`; version via `-X`.
- [ ] Minimal base (distroless/static or scratch); CA certs present.
- [ ] Runs as non-root; base pinned by digest.
- [ ] `.dockerignore` trims the context; no secrets in `ARG`/`ENV`.
- [ ] Health via orchestrator probes (no shell in distroless/scratch).
