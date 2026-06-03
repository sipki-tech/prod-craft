# Clean Architecture in Go

Based on the layered monolith pattern used in production Go services.

## The Dependency Rule
Dependencies point **inward** toward the domain. Inner layers know nothing about outer layers. The app layer defines interfaces; outer layers implement them.

```text
Transport (gRPC / REST gateway / HTTP files / Telegram)
   ↓
Application (App + TracedApp wrapper with OpenTelemetry)
   ↓
Adapters (Repo, Auth, PasswordHash, FileStore, Sessions, Cache)
   ↓
Infrastructure (PostgreSQL, Redis, S3-compatible storage)
```

## Forbidden Imports Matrix
Enforce the dependency rule mechanically with `depguard` (see `toolkit/linting.md`). These imports are violations:

| Package | MUST NOT import |
|---|---|
| `internal/app` | `api/**`, `google.golang.org/grpc`, `net/http`, any `adapters/*` |
| `internal/apptracing` | `adapters/**`, `api/**` |
| `internal/adapters/*` | other `adapters/*`, `api/**`, `apptracing` |
| `internal/api/*` (transport) | `adapters/**` |
| top-level `internal/**` (shared libs) | anything under `cmd/**` |

If the app layer needs `grpc` or a concrete adapter, the layering is broken — introduce or extend an interface in `app/contracts.go` instead.

## Layer Breakdown

### 1. `cmd/app/internal/app/` — Application Layer
Contains all business logic. This is the core of the system.

Key files:
- **`app.go`** — The `App` struct. Holds references to all dependency interfaces. Has a single `New()` constructor.
- **`contracts.go`** — All interfaces the app layer needs (`Repo`, `Auth`, `Sessions`, `FileStore`, `PasswordHash`, `EmailSender`, etc.).
- **`domain.go`** — Domain structs (`User`, `Session`, `Token`, `File`), enums, and value objects specific to this application.
- **`error.go`** — All sentinel errors (`ErrNotFound`, `ErrEmailExist`, `ErrAccessDenied`, etc.).
- **`handlers.go`** — Business logic methods on `*App`.

**Allowed:** Pure business logic, calls to interface methods, domain types.
**Forbidden:** HTTP/gRPC types, SQL, Redis commands, external library imports (except UUIDs and domain types).

```go
// App struct — thin, just holds dependencies
type App struct {
    repo       Repo
    hash       PasswordHash
    auth       Auth
    id         ID
    sessions   Sessions
    file       FileStore
    downloader Downloader
    oauth      map[string]OAuthProvider
    email      EmailSender
}

func New(r Repo, ph PasswordHash, a Auth, id ID, s Sessions, ...) *App {
    return &App{repo: r, hash: ph, auth: a, id: id, sessions: s, ...}
}
```

### 2. `cmd/app/internal/apptracing/` — Tracing Decorator
A pass-through wrapper that adds OpenTelemetry spans to every `App` method. It implements the same interface as `App` but is NOT business logic.
- **Reason:** Keeps business logic clean from observability concerns. Every new method on `App` must be mirrored in `TracedApp`.

```go
type TracedApp struct {
    app    Application
    tracer trace.Tracer
}

func (t *TracedApp) CreateUser(ctx context.Context, ...) (uuid.UUID, error) {
    ctx, span := t.tracer.Start(ctx, "App.CreateUser")
    defer span.End()
    return t.app.CreateUser(ctx, ...)
}
```

**Span naming convention:** `App.MethodName` for app-layer methods, `Repo.MethodName` for repo-layer methods.

### 3. `cmd/app/internal/adapters/` — Adapter Layer
Implements the interfaces defined in `app/contracts.go`. Each adapter lives in its own sub-package:
- `adapters/repo/` — PostgreSQL repository (implements `app.Repo`).
- `adapters/cache/redis/` — Redis cache, sessions, leader election.
- `adapters/files/` — S3-compatible file storage (implements `app.FileStore`).
- `adapters/oauth/` — OAuth providers (Google, GitHub, Apple, Yandex).
- `adapters/email/` — Email sender (Resend).
- `adapters/downloader/` — HTTP file downloader.

**Allowed:** SQL queries, Redis commands, HTTP client calls, driver-specific code.
**Forbidden:** Business logic, decision-making beyond data mapping.

### 4. `cmd/app/internal/api/` — Transport Layer
Converts external requests into app-layer calls. Each transport lives in its own sub-package:
- `api/grpc/` — gRPC server implementation.
- `api/http/` — HTTP file server.
- `api/telegram/` — Telegram bot handlers.

**Allowed:** Request parsing, response formatting, auth middleware, error code mapping.
**Forbidden:** Direct database access, business logic.

### 5. `internal/` — Shared Infrastructure Libraries
Reusable packages shared across all binaries in the monorepo:
- `internal/database/` — DB connection helpers.
- `internal/logger/` — Structured logging with context propagation.
- `internal/grpchelper/` — gRPC interceptors and error converters.
- `internal/serve/` — Parallel service runner using `errgroup`.
- `internal/metrics/` — Prometheus metrics wrapper.
- `internal/password/` — Argon2 password hashing.
- `internal/testhelper/` — Test context and Docker container helpers.
- `internal/dom/` — Shared domain types (enums, events).

## Where Does It Go?
| Thing | Home |
|---|---|
| New business rule / use case | `app/handlers.go` (+ mirror a span in `apptracing`) |
| New infra capability | new method on an interface in `app/contracts.go`, implemented in `adapters/<infra>` |
| New RPC endpoint | `api/<svc>/vN/*.proto` → `api/grpc/handlers.go` |
| New domain enum / value object | `internal/dom` (with stringer) |
| New cross-adapter sentinel error | `internal/dom` |
| New app-only sentinel error | `app/error.go` |
| New SQL query | `adapters/repo/<area>_handlers.go` + row model in `<area>_model.go` |
| Schema change | new file in `cmd/app/migrate/` (never edit an applied migration) |
| Bootstrap / wiring / leader-only loop | `cmd/app/main.go` |
| Reusable, non-domain helper | top-level `internal/<lib>` |

## Repo ↔ txRepo Symmetry
The transactional and non-transactional repositories implement the **same** `Repo` interface. Every method exists on both with identical behavior; only `Repo.Tx` opens a transaction, and the inner `txRepo.Tx` panics (a nested transaction is a bug). Detail and the closure pattern: `architecture/transactions.md`.

## Wiring in `main.go`
`main.go` is the composition root. It instantiates adapters, passes them to `app.New()`, wraps the app with `apptracing.New()`, builds transport servers, and starts them all in parallel using `serve.Start()`.

```go
func run(ctx context.Context, cfg config, ...) error {
    r, fileStore, cleanup, err := initInfrastructure(ctx, cfg, ...)
    defer cleanup()

    module := app.New(r, ph, authModule, idGen, sessionStore, fileStore, ...)
    tracedModule := apptracing.New(module)
    grpcServer := grpc.New(ctx, m, tracedModule, ...)

    return serve.Start(ctx,
        serve.GRPC(log, host, port, grpcServer),
        serve.GRPCGateWay(log, host, gwPort, gwCfg),
        serve.HTTP(log, host, filePort, httpHandler),
        serve.Telegram(log, tgBot),
    )
}
```

## `serve.Start` Pattern
Use `errgroup` to run all services in parallel. If any service fails, the group's context is cancelled, and all other services shut down.
- **Reason:** Ensures clean, coordinated shutdown. No goroutine is left running after an error.

```go
func Start(ctx context.Context, services ...func(context.Context) error) error {
    g, groupCtx := errgroup.WithContext(ctx)
    for i := range services {
        g.Go(func() error { return services[i](groupCtx) })
    }
    return g.Wait()
}
```

## Mock Generation
Generate mocks from `contracts.go` using `mockgen` with `//go:generate` in a `generate_test.go` file inside the `_test` package.
- **Reason:** Keeps mock code out of production builds and co-located with tests.

```go
// cmd/app/internal/app/generate_test.go
package app_test

//go:generate mockgen -source=contracts.go -destination mock.app.contracts_test.go -package app_test
```
