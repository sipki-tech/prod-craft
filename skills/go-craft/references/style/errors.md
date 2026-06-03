# Error Handling in Go

Errors in Go are values. Treat them with the same care as any other data.

## Error Wrapping with Call Chain
Use `fmt.Errorf` with `%w` to wrap errors. The message must include the **call chain** — the receiver, method, or function that returned the error.
- **Reason:** When a wrapped error surfaces in logs, the call chain tells you exactly which layer and which call failed without needing a stack trace.

```go
// Good — call chain is clear
if err != nil {
    return fmt.Errorf("a.repo.UserByEmail: %w", err)
}

if err != nil {
    return fmt.Errorf("repo.SaveTask: %w", err)
}

// Bad — no call chain context
if err != nil {
    return fmt.Errorf("failed to get user: %w", err) // Which call failed?
}

// Bad — loses the original error type
if err != nil {
    return fmt.Errorf("a.repo.UserByEmail: %v", err)
}
```

## Error Message Style
Error strings are lowercase, have no trailing punctuation, and contain **no business logic** or data. Callers branch on sentinel values and codes, not on message text.
- **Reason:** `revive`/`staticcheck` flag capitalized or punctuated error strings. Messages get wrapped, so a capital + period produces `"repo.X: Failed.: ..."`.

```go
// Good
errors.New("invalid token")
fmt.Errorf("repo.UserByID: %w", err)

// Bad
errors.New("Invalid token.")         // capitalized + trailing period
errors.New("user 42 is not allowed") // business logic / data in the message
```

## Sentinel Errors in the App Layer
Declare expected domain errors as package-level variables in a single `error.go` file within the app package. Name them `ErrXxx`.
- **Reason:** Callers can use `errors.Is` to check for specific failure conditions. Centralizing them in one file makes the error contract explicit and discoverable.

```go
// Good — cmd/app/internal/app/error.go
package app

import "errors"

var (
    ErrNotFound        = errors.New("not found")
    ErrEmailExist      = errors.New("email exist")
    ErrUsernameExist   = errors.New("username exist")
    ErrInvalidPassword = errors.New("invalid password")
    ErrInvalidToken    = errors.New("invalid token")
    ErrExpiredToken    = errors.New("expired token")
    ErrAccessDenied    = errors.New("access denied")
)
```

## Convert Errors at the Boundary (driver → domain)
Adapters MUST convert infrastructure errors into domain sentinels before returning. Never let a driver error (`sql.ErrNoRows`, `*pgconn.PgError`, `redis.Nil`) escape into the app layer.
- **Reason:** The app layer routes on `app.Err*`. If it had to recognize `pgx`/`redis` error types, the dependency rule (see `architecture/clean.md`) would be broken and the app would couple to infrastructure.

```go
// adapters/repo/error.go — one convertErr per adapter
func convertErr(err error) error {
    switch {
    case err == nil:
        return nil
    case errors.Is(err, sql.ErrNoRows):
        return app.ErrNotFound
    case isUniqueViolation(err, "users_email_key"):
        return app.ErrEmailExist
    default:
        return err // unknown infra error; caller wraps it with a call chain
    }
}

func isUniqueViolation(err error, constraint string) bool {
    var pgErr *pgconn.PgError
    return errors.As(err, &pgErr) && pgErr.Code == "23505" &&
        pgErr.ConstraintName == constraint
}

// in the method:
func (r *Repo) UserByEmail(ctx context.Context, email string) (*app.User, error) {
    var row userRow
    err := r.db.GetContext(ctx, &row, queryUserByEmail, email)
    if err != nil {
        return nil, fmt.Errorf("db.GetContext: %w", convertErr(err))
    }
    return row.toDomain(), nil
}
```

The full chain end-to-end: **driver error → adapter `convertErr` → `app.Err*` sentinel → transport `convertErr` → gRPC code / HTTP status.**

## Switch-Style Error Handling
Use `switch` with `errors.Is` when a function can return multiple known sentinel errors. This is cleaner than chained `if/else` blocks.
- **Reason:** The `switch` pattern provides exhaustive, scannable error routing at call sites. It makes it clear which errors are explicitly handled.

```go
// Good — switch on error
user, err := a.repo.UserByEmail(ctx, email)
switch {
case errors.Is(err, ErrNotFound):
    return nil // Not an error in this context
case err == nil:
    return ErrEmailExist
default:
    return fmt.Errorf("a.repo.ByEmail: %w", err)
}

// Bad — nested if/else
user, err := a.repo.UserByEmail(ctx, email)
if err != nil {
    if errors.Is(err, ErrNotFound) {
        return nil
    }
    return fmt.Errorf("a.repo.ByEmail: %w", err)
}
return ErrEmailExist
```

## Typed Errors with `errors.As`
When an error must carry data (a field name, a retry-after), define a struct type implementing `error` and unwrap it with `errors.As`. Use sentinels for "which error"; use typed errors for "which error + details".
- **Reason:** `errors.Is` answers identity; `errors.As` extracts a payload from anywhere in the wrap chain.

```go
type ValidationError struct {
    Field  string
    Reason string
}

func (e *ValidationError) Error() string {
    return fmt.Sprintf("validation: %s: %s", e.Field, e.Reason)
}

// caller
var ve *ValidationError
if errors.As(err, &ve) {
    return badRequest(ve.Field, ve.Reason)
}
```

## Document Errors on Interface Methods
Every interface method's godoc must list the sentinel errors it can return. Use the format: `// Errors: ErrX, ErrY, unknown.`
- **Reason:** The `app` layer builds its `switch` logic based on these documented errors. `unknown` signals infrastructure errors that the app should wrap and propagate.

```go
// Good
type Repo interface {
    // UserByEmail returns user info by email.
    // Errors: ErrNotFound, unknown.
    UserByEmail(ctx context.Context, email string) (*User, error)
    // UserSave adds to the new user to repository.
    // Errors: ErrEmailExist, ErrUsernameExist, unknown.
    UserSave(ctx context.Context, user User) (uuid.UUID, error)
}
```

## gRPC Error Conversion
Do not return raw domain errors over gRPC. Use a dedicated converter interceptor that maps `app.Err*` sentinels to `codes.*` gRPC status codes.
- **Reason:** gRPC clients expect standard status codes. Leaking domain errors exposes internal details and breaks protocol contracts.

```go
// Good — centralized converter as a gRPC interceptor
func convertErr(err error) *status.Status {
    switch {
    case errors.Is(err, app.ErrNotFound):
        return status.New(codes.NotFound, err.Error())
    case errors.Is(err, app.ErrInvalidPassword):
        return status.New(codes.Unauthenticated, err.Error())
    case errors.Is(err, app.ErrAccessDenied):
        return status.New(codes.PermissionDenied, err.Error())
    default:
        return status.New(codes.Internal, err.Error())
    }
}

// Register as a server interceptor (see recipes/middleware.md for the chain):
srv := grpc.NewServer(grpc.ChainUnaryInterceptor(convertErrInterceptor(convertErr)))
```

## Avoid `panic`
Do not use `panic` for normal error handling. Only panic during startup for truly unrecoverable errors (missing config, unknown enum values in exhaustive converters).
- **Reason:** Panics crash the application. Reserve them for programmer bugs, not runtime conditions.

```go
// Acceptable — exhaustive enum converter
func UserStatusToAPI(status UserStatus) pb.StatusKind {
    switch status {
    case UserStatusDefault:
        return pb.StatusKind_STATUS_KIND_DEFAULT
    // ... other cases ...
    default:
        panic(fmt.Sprintf("unknown status: %s", status))
    }
}
```
