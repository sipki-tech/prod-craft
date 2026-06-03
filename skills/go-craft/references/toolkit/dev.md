# Development Toolkit & Workflows

Automate repetitive tasks to stay focused on writing code.

## Task Runner (`Taskfile.yml`)
Use [Task](https://taskfile.dev) instead of `make` as the primary task runner. Define standard targets: `init`, `build`, `test-unit`, `test-integration`, `lint`, `up`, `down`.
- **Reason:** Task is cross-platform, uses YAML, and supports dependencies, dotenv loading, and preconditions natively. It's more predictable than Makefiles.

```yaml
version: "3"

tasks:
  test-unit:
    cmds:
      - "gotestsum --format pkgname -- -coverprofile=cover.out -race -count=1 ./..."

  test-integration:
    cmds:
      - "gotestsum --format pkgname -- -tags=integration -race -count=1 ./..."

  build:
    cmds:
      - "go build -o bin/ ./cmd/app/"
      - docker compose build
      - docker compose pull

  lint:
    deps: [test-unit, build]
    cmds:
      - "go get -v ./..."
      - "golangci-lint run ./..."
      - "buf lint"

  up:
    deps: [init, build-linux]
    dotenv: [".env"]
    cmds:
      - "docker compose up --build --remove-orphans --detach"

  down:
    cmds:
      - "docker compose down --volumes"
```

## Code Generation (`go generate`)
Use the `//go:generate` directive to specify how code should be generated. Two main use cases:
1. **Mock generation** — `mockgen` from `go.uber.org/mock`.
2. **Stringer** — `stringer` for enum `String()` methods.

- **Reason:** Keeps generation commands co-located with the code that requires them.

```go
// Mock generation (in generate_test.go)
//go:generate mockgen -source=contracts.go -destination mock.app.contracts_test.go -package app_test

// Stringer for enums (in domain.go)
//go:generate stringer -output=stringer.TaskKind.go -type=TaskKind -trimprefix=TaskKind
//go:generate stringer -output=stringer.UserStatus.go -type=UserStatus -trimprefix=UserStatus
```

## Enum Pattern with `stringer`
Define enums as `uint8` typed constants with iota. Use `//go:generate stringer` to auto-generate the `String()` method. Always start with a blank `_` entry to make zero-value invalid.
- **Reason:** Zero-value enums should be invalid to catch uninitialized fields. `-trimprefix` produces clean output without the type prefix.

```go
type TaskKind uint8

//go:generate stringer -output=stringer.TaskKind.go -type=TaskKind -trimprefix=TaskKind
const (
    _ TaskKind = iota
    TaskKindEventUserAdd
    TaskKindEventUserDel
    TaskKindEventUserUpdate
)
```

## Structured Logging
Use `log/slog` (standard library) with JSON handler. Propagate the logger via `context.Context`. Define log keys as typed constants with `stringer`.
- **Reason:** Structured JSON logs are machine-parseable. Context propagation ensures request-scoped logger enrichment (trace IDs, versions). Typed keys prevent typos.

```go
// internal/logger/keys.go
type LogKey uint8

//go:generate stringer -output=stringer.LogKey.go -type=LogKey -linecomment
const (
    _       LogKey = iota
    Version        // version
    Error          // err
    Module         // module
    Host           // host
    Port           // port
)

// Usage
log.Error("shutdown", slog.String(logger.Error.String(), err.Error()))
```

### Logger Context Propagation
```go
// internal/logger/context.go
func NewContext(ctx context.Context, logger *slog.Logger) context.Context {
    return context.WithValue(ctx, ctxMarker{}, logger)
}

func FromContext(ctx context.Context) *slog.Logger {
    l, ok := ctx.Value(ctxMarker{}).(*slog.Logger)
    if !ok {
        return slog.Default()
    }
    return l
}
```

## Proto Tooling
Use `buf` (or the drop-in alternative [EasyP](https://easyp.tech)) for linting, breaking-change checks, and code generation of `.proto` files. Proto files are the source of truth for API contracts. Generated code (`*.pb.go`, `*.pb.gw.go`, `*.swagger.json`) is committed to the repo.

## Debugging with Delve (`dlv`)
Use Delve (`dlv`) for step-through debugging.
```bash
dlv debug ./cmd/app
```
