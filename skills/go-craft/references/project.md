# Standard Go Project Layout

Adapted from `golang-standards/project-layout` and refined by real production monolith patterns.

## Top-Level Directories

| Directory | Purpose |
|---|---|
| `cmd/` | Entry points. One subdirectory per binary (e.g., `cmd/app/main.go`). |
| `internal/` | Shared private libraries (logger, database, grpchelper, serve, metrics, testhelper, dom). |
| `cmd/app/internal/` | Application-specific layers (app, adapters, api, apptracing, auth, session). |
| `api/` | Proto definitions — the source of truth for API contracts. Generated code is committed. |
| `configs/` | Config files for infrastructure (Grafana, Traefik, etc.). |
| `scripts/` | Helper scripts (build env, CI). |
| `clients/` | Frontend clients (web, telegram, mobile). |

## Two Levels of `internal/`
Use two levels of `internal/` to separate shared infrastructure from app-specific code.
- **Reason:** Top-level `internal/` is shared across binaries. `cmd/app/internal/` is private to that binary.

```text
myapp/
├── cmd/app/
│   ├── main.go
│   ├── config.yml
│   ├── migrate/              # SQL migrations
│   └── internal/             # App-specific layers
│       ├── app/              # Business logic + contracts + domain + errors
│       ├── adapters/         # Repo, cache, files, email, oauth, downloader
│       │   ├── repo/
│       │   ├── cache/redis/
│       │   ├── files/
│       │   ├── oauth/
│       │   ├── email/
│       │   └── downloader/
│       ├── api/              # Transport: grpc, http, telegram
│       │   ├── grpc/
│       │   ├── http/
│       │   └── telegram/
│       ├── apptracing/       # OpenTelemetry decorator
│       ├── auth/             # Token module
│       └── session/          # Session store
├── internal/                 # Shared infra libraries
│   ├── database/
│   ├── logger/
│   ├── grpchelper/
│   ├── serve/
│   ├── metrics/
│   ├── password/
│   ├── testhelper/
│   ├── dom/                  # Shared domain types (enums, events)
│   └── version/
├── api/                      # Proto definitions (source of truth)
│   └── <service>/v1/*.proto
├── configs/                  # Grafana Alloy, Loki, Mimir, Tempo, Pyroscope, Traefik
├── clients/
│   ├── web/
│   └── telegram/
├── scripts/
├── docker-compose.yml
├── Taskfile.yml
├── go.mod
└── go.sum
```

## `go.mod` and `go.sum`
Both files MUST be committed.
- **Reason:** `go.sum` ensures cryptographic integrity of downloaded modules.

## Configuration
Use YAML config files (e.g., `cmd/app/config.yml`) loaded into strongly typed structs. Never read `os.Getenv` directly from business logic.
- **Reason:** Typed config structs are self-documenting and validated at startup.

```go
// Config structs with yaml tags in snake_case
type config struct {
    Server  server   `yaml:"server"`
    DB      dbConfig `yaml:"db"`
    AuthKey string   `yaml:"auth_key"`
    DevMode bool     `yaml:"dev_mode"`
    Cache   cache    `yaml:"cache"`
}
```

## What NOT to put in the Repo Root
Never put `main.go` in the repository root. Do not place business logic directly in the root. Do not commit `bin/`, `.cover/`, `.env`, or local secrets.
