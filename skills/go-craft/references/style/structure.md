# Go Project Structure & Package Design

Proper package organization makes Go code maintainable and prevents circular dependencies. These rules are derived from real production Go monoliths.

## Package Cohesion
Group code by domain or behavior, NOT by kind. Avoid packages named `utils`, `common`, `helpers`, or `models`.
- **Reason:** `utils` becomes a dumping ground for unrelated code, leading to circular dependencies. Packages should have a single, clear purpose.

```go
// Good
package user      // contains User struct, Repository, Usecase
package password  // specific utility
package logger    // focused concern

// Bad
package models    // groups all structs together
package utils     // mixed grab-bag
```

## Interface Placement
Define interfaces where they are **used** (in the consumer), not where they are implemented. This is summarized as: "Accept interfaces, return structs."
- **Reason:** The consumer dictates the shape of the interface it needs. This minimizes coupling and the interface surface.

In a clean architecture Go monolith, the **app (usecase) layer** defines the contracts that adapters must satisfy:

```go
// Good: App layer defines the interfaces it needs.
// cmd/app/internal/app/contracts.go
package app

type Repo interface {
    // UserSave adds to the new user to repository.
    // Errors: ErrEmailExist, ErrUsernameExist, unknown.
    UserSave(ctx context.Context, user User) (uuid.UUID, error)
    // UserByID returns user info by id.
    // Errors: ErrNotFound, unknown.
    UserByID(ctx context.Context, id uuid.UUID) (*User, error)
    // Tx starts transaction in database.
    // Errors: unknown.
    Tx(ctx context.Context, f func(Repo) error) error
}

type PasswordHash interface {
    Hashing(ctx context.Context, password string) ([]byte, error)
    Compare(ctx context.Context, hashedPassword []byte, password []byte) bool
}

type Sessions interface {
    SessionSave(ctx context.Context, session Session) error
    SessionByID(ctx context.Context, id uuid.UUID) (*Session, error)
    SessionDelete(ctx context.Context, id uuid.UUID) error
}
```

## Document Interface Errors in Comments
For every interface method, document the possible domain errors in the godoc comment using the format `// Errors: ErrX, ErrY, unknown.`
- **Reason:** The caller (app layer) needs to know which sentinel errors to expect from each method to build correct `switch` logic. `unknown` signals infrastructure errors that should be wrapped and bubbled up.

```go
// Good
type Repo interface {
    // UserByEmail returns user info by email.
    // Errors: ErrNotFound, unknown.
    UserByEmail(ctx context.Context, email string) (*User, error)
}

// Bad
type Repo interface {
    UserByEmail(ctx context.Context, email string) (*User, error) // No error docs
}
```

## Group Related Types with `type()` Blocks
Group related type declarations (structs, interfaces) in a single `type ()` block, separated by comments.
- **Reason:** It provides a visual signal that these types belong to the same conceptual domain.

```go
// Good
type (
    // User contains user information.
    User struct {
        ID       uuid.UUID
        Email    string
        Name     string
        PassHash []byte
        Status   dom.UserStatus
    }

    // Token contains auth token.
    Token struct {
        Value string
    }

    // Session contains session info for identify a user.
    Session struct {
        ID     uuid.UUID
        Origin Origin
        Token  Token
        UserID uuid.UUID
    }
)
```

## Keeping `main.go` Thin
The `main()` function should only parse flags, build a logger, set up signal handling, and call a `start()` function. All wiring goes into `start()` or dedicated `init*()` helpers. Business logic never lives in `main.go`.
- **Reason:** It makes the core application testable without booting up the entire binary.

```go
// Good
func main() {
    flag.Parse()
    log := buildLogger(logLevel.Level)

    ctx, cancel := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
    defer cancel()
    go forceShutdown(ctx)

    if err := start(ctx, cfgFile, appName); err != nil {
        log.Error("shutdown", slog.String("err", err.Error()))
        os.Exit(2)
    }
}
```

## Using `internal/` Packages
Place application-specific code inside an `internal/` directory. Use two levels of `internal/`:
- **Top-level `internal/`** — reusable libraries shared across binaries (logger, database, grpchelper, password, serve, metrics, testhelper, dom).
- **`cmd/app/internal/`** — application-specific layers (app, adapters, api, apptracing, auth, session).

- **Reason:** The Go compiler prevents external imports of `internal/` code. Two levels lets you share infra code within the monorepo while keeping app logic private.

```text
// Good Structure
myapp/
├── cmd/app/
│   ├── main.go
│   └── internal/          // App-specific layers
│       ├── app/           // Business logic + contracts
│       ├── adapters/      // Repo, cache, files, email, oauth
│       ├── api/           // Transport: grpc, http, telegram
│       ├── apptracing/    // OpenTelemetry decorator
│       ├── auth/          // Token module
│       └── session/       // Session store
├── internal/              // Shared infra libraries
│   ├── database/
│   ├── logger/
│   ├── grpchelper/
│   ├── serve/
│   ├── metrics/
│   ├── password/
│   ├── testhelper/
│   └── dom/               // Shared domain types (enums, events)
└── api/                   // Proto definitions (source of truth)
```

## Shared Domain Package (`dom`)
Place cross-cutting domain types (enums, events, value objects that are shared between the proto boundary and the app layer) in a dedicated `internal/dom/` package.
- **Reason:** Prevents import cycles between `app` and proto-generated packages. Enums like `UserStatus` with business-method helpers (`IsAdmin()`, `IsVerified()`) live here and are used by both layers.

```go
// internal/dom/user_status.go
type UserStatus uint8

const (
    _ UserStatus = iota
    UserStatusFreeze
    UserStatusDefault
    UserStatusPremium
    UserStatusAdmin
)

func (i UserStatus) IsAdmin() bool   { return i == UserStatusAdmin }
func (i UserStatus) IsVerified() bool { return i != UserStatusFreeze }
```
