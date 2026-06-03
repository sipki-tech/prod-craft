# `go-craft` Navigation Map

Load only the files relevant to your current task. Each row says when to read it. Two cross-cutting rules underpin everything: **errors are documented domain values** (`style/errors.md`) and **every test is parallel** (`testing/parallel.md`).

## 🎨 Style

| File | When to Read |
|---|---|
| [`style/naming.md`](./references/style/naming.md) | Naming packages, vars, interfaces, acronyms; avoiding stutter; getters. |
| [`style/errors.md`](./references/style/errors.md) | Wrapping with `%w`, sentinels, `errors.Is`/`As`, boundary conversion, `// Errors:` docs. |
| [`style/concurrency.md`](./references/style/concurrency.md) | Goroutine lifecycle, panic recovery in goroutines, `errgroup` runner + pools, channels, mutex, `-race`. |
| [`style/context.md`](./references/style/context.md) | `ctx`-first, no-store, no `Background()` in business code, propagation, deadlines. |
| [`style/structure.md`](./references/style/structure.md) | Package cohesion, consumer-defined interfaces, thin `main`, the `dom` package. |
| [`style/interfaces.md`](./references/style/interfaces.md) | Accept interfaces/return structs, small contracts, compile-time assertions, typed-nil. |
| [`style/structs.md`](./references/style/structs.md) | Useful zero values, constructors, field order, tags, embedding, layer models. |
| [`style/functions.md`](./references/style/functions.md) | Param order, error-last, named-return policy, functional options, receivers. |
| [`style/enums.md`](./references/style/enums.md) | `uint8`+iota, invalid zero, stringer, helpers, exhaustive conversion. |
| [`style/comments.md`](./references/style/comments.md) | Godoc conventions, the "why" not "what", generated markers, TODO ownership. |
| [`style/time.md`](./references/style/time.md) | `time.Time`/`Duration`, UTC, named durations, injectable `Clock`. |
| [`style/slices-maps.md`](./references/style/slices-maps.md) | Prealloc, nil-vs-empty, comma-ok, aliasing, `slices`/`maps` helpers. |
| [`style/generics.md`](./references/style/generics.md) | When (and when not) to use type parameters; constraints. |

## 🏗️ Architecture

| File | When to Read |
|---|---|
| [`project.md`](./references/project.md) | Standard layout (`cmd/`, `internal/`, two-level `internal/`, `api/`). |
| [`architecture/clean.md`](./references/architecture/clean.md) | Dependency rule, forbidden-imports matrix, where-does-it-go table, layer breakdown. |
| [`architecture/decorator.md`](./references/architecture/decorator.md) | Interface decorators for tracing/caching/metrics; "wrap don't pollute". |
| [`architecture/domain-modeling.md`](./references/architecture/domain-modeling.md) | Entities vs value objects, shared kernel, per-layer models + converters. |
| [`architecture/transactions.md`](./references/architecture/transactions.md) | `Tx(ctx, func(Repo) error)` closure, repo/txRepo symmetry, retries, no I/O in tx. |
| [`architecture/wiring.md`](./references/architecture/wiring.md) | Composition root, constructor DI, ordered cleanup, leader-only loops. |
| [`architecture/messaging.md`](./references/architecture/messaging.md) | Outbox + Inbox/idempotent consumer, Saga + compensation, eventual consistency, patterns-to-avoid. |

## 🗄️ Data

| File | When to Read |
|---|---|
| [`data/database.md`](./references/data/database.md) | Repository pattern, `sqlx`/`squirrel`, parameterized SQL, pooling, N+1, error mapping. |
| [`data/migrations.md`](./references/data/migrations.md) | Sequential immutable migrations, type choices, indexes, zero-downtime 3-phase. |
| [`data/caching.md`](./references/data/caching.md) | Redis cache-aside decorator, `singleflight` stampede control, key namespacing, TTL, atomic ops, leader election. |

## 🧪 Testing

| File | When to Read |
|---|---|
| [`testing/unit.md`](./references/testing/unit.md) | Black-box `_test`, table-driven cases, require vs assert, edge-case checklist. |
| [`testing/parallel.md`](./references/testing/parallel.md) | **Mandatory `t.Parallel()`**; refactor the code if a test can't be parallel. |
| [`testing/mocking.md`](./references/testing/mocking.md) | gomock (`go.uber.org/mock`), `mockgen`, `mocks` struct, `start(t)`, `DoAndReturn`. |
| [`testing/integration.md`](./references/testing/integration.md) | `//go:build integration`, container helpers, namespacing, `require.Eventually`. |
| [`testing/fixtures-golden.md`](./references/testing/fixtures-golden.md) | Package fixtures, `testdata/`, golden files + `-update`, `t.TempDir()`. |
| [`testing/benchmarks.md`](./references/testing/benchmarks.md) | `testing.B`/`b.Loop`, `-benchmem`, `benchstat`, `pprof` (CPU/heap/block/mutex), escape analysis, `sync.Pool`. |

## 🛠️ Toolkit

| File | When to Read |
|---|---|
| [`toolkit/linting.md`](./references/toolkit/linting.md) | Discover linters (`linters`/catalog), `golangci-lint` v2 config, tiers, `//nolint` policy, formatters. |
| [`toolkit/testing.md`](./references/toolkit/testing.md) | Testing overview (entry point to the `testing/` guides). |
| [`toolkit/protobuf.md`](./references/toolkit/protobuf.md) | `buf` (or EasyP) config, lint/breaking/gen, committing generated code. |
| [`toolkit/dev.md`](./references/toolkit/dev.md) | Task runner, `go:generate`, stringer, slog logger + context. |
| [`toolkit/observability.md`](./references/toolkit/observability.md) | slog + OpenTelemetry span naming + error recording, Prometheus, profiling. |
| [`toolkit/ci.md`](./references/toolkit/ci.md) | `task lint`, `-race`, PR-scoped lint, `govulncheck`, generated-artifact freshness. |
| [`toolkit/modules.md`](./references/toolkit/modules.md) | `go.mod`/`go.sum`, tidy/verify, SemVer import, MVS upgrades, `replace`/`go.work`, vendoring, govulncheck. |
| [`toolkit/docker.md`](./references/toolkit/docker.md) | Multi-stage build, static binary (`CGO_ENABLED=0`/`-trimpath`/`-ldflags -X`), distroless/scratch, non-root, digest pin. |

## 🍳 Recipes

| File | When to Read |
|---|---|
| [`recipes/middleware.md`](./references/recipes/middleware.md) | HTTP middleware (slog log, recovery, auth, chaining) + gRPC interceptor analog. |
| [`recipes/graceful-shutdown.md`](./references/recipes/graceful-shutdown.md) | `signal.NotifyContext` + `errgroup` + force-kill safety net. |
| [`recipes/config.md`](./references/recipes/config.md) | Typed YAML config, flag loading, validate on startup. |
| [`recipes/grpc-api.md`](./references/recipes/grpc-api.md) | Method shape, error→code mapping, cursor pagination, idempotency, versioning. |
| [`recipes/background-jobs.md`](./references/recipes/background-jobs.md) | Transactional outbox + leader-only worker loop; idempotent handlers. |
| [`recipes/file-storage.md`](./references/recipes/file-storage.md) | S3-compatible `FileStore`: stream not buffer, sniff type, multipart, presigned vs proxied, lifecycle. |
| [`recipes/outbound-http.md`](./references/recipes/outbound-http.md) | Tuned client + timeouts, retry/backoff+jitter, circuit breaker, idempotency key, SSRF guard. |
| [`recipes/health-checks.md`](./references/recipes/health-checks.md) | Liveness vs readiness, parallel dependency checks, readiness drains first on shutdown. |
| [`recipes/rate-limiting.md`](./references/recipes/rate-limiting.md) | Inbound limits: key choice, token bucket, `429`+`Retry-After`, distributed via Redis, bounded maps. |
| [`recipes/validation.md`](./references/recipes/validation.md) | Parse-don't-validate at the edge, value-object constructors, generated wire validation, error mapping. |
| [`recipes/server-hardening.md`](./references/recipes/server-hardening.md) | HTTP timeouts (slowloris), `MaxBytesReader`, gRPC message-size caps + keepalive enforcement. |

## 🔒 Security

| File | When to Read |
|---|---|
| [`security/security.md`](./references/security/security.md) | OWASP map, argon2id, constant-time compare, validation, secrets, PII, SSRF, uploads. |
| [`security/auth.md`](./references/security/auth.md) | Login (no enumeration), revocable sessions, OAuth state/nonce/PKCE, access control. |
| [`security/oauth.md`](./references/security/oauth.md) | Provider behind interface, ID-token via JWKS, `aud`/`iss`/`nonce`, PKCE, account-linking, token rotation. |

## 📦 Assets (copy-paste starters)

| File | Use |
|---|---|
| [`assets/golangci.yml`](./assets/golangci.yml) | golangci-lint v2 starter config. |
| [`assets/Taskfile.yml`](./assets/Taskfile.yml) | Task runner with init/build/test/lint/vuln targets. |
| [`assets/contracts.go.tmpl`](./assets/contracts.go.tmpl) | App-layer interface skeleton with `// Errors:` docs. |
| [`assets/app_test_skeleton.go.tmpl`](./assets/app_test_skeleton.go.tmpl) | `start(t)` + table-driven + gomock parallel test. |
| [`assets/migration_phase.sql.tmpl`](./assets/migration_phase.sql.tmpl) | Zero-downtime expand/migrate/contract migration. |
| [`assets/Dockerfile`](./assets/Dockerfile) | Multi-stage Go build → distroless/static, non-root, version via `-ldflags -X`. |
| [`assets/.dockerignore`](./assets/.dockerignore) | Build-context ignore list (VCS, `bin/`, env, CI files). |
