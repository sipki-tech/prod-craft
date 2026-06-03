# Multi-stage Dockerfile for a Go service. See ../references/toolkit/docker.md.
# Build: docker build --build-arg VERSION=$(git describe --tags --always) -t app .

# ---- build stage ----
# Pin by digest in production, e.g. golang:1.23@sha256:<digest>
FROM golang:1.23 AS build

WORKDIR /src

# Cache dependencies in their own layer (re-runs only when go.mod/go.sum change).
COPY go.mod go.sum ./
RUN go mod download

# Build a static, trimmed binary with the version embedded.
COPY . .
ARG VERSION=dev
ARG TARGETOS=linux
ARG TARGETARCH=amd64
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
    go build -trimpath -ldflags="-s -w -X main.version=${VERSION}" -o /out/app ./cmd/app

# ---- runtime stage ----
# distroless/static: CA certs + tzdata + nonroot user, no shell, no package manager.
FROM gcr.io/distroless/static:nonroot

COPY --from=build /out/app /app

USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/app"]
