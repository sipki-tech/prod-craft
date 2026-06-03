# Function & Method Design

Functions are the unit of behavior. Keep signatures honest, returns predictable, and options idiomatic.

## Parameter Order
`context.Context` first, then the most important domain inputs, then options/flags last.
- **Reason:** A predictable order makes call sites scannable and matches the rest of the ecosystem.

```go
func (a *App) ListUsers(ctx context.Context, filter Filter, page Page) ([]User, error)
```

## Return `error` Last
The error is always the final return value. Return early on error; keep the happy path un-indented.
- **Reason:** Universal convention; early returns avoid an "arrow" of nested `if`s.

```go
// Good
u, err := a.repo.UserByID(ctx, id)
if err != nil {
    return nil, fmt.Errorf("repo.UserByID: %w", err)
}
return u, nil
```

## Named Returns: Sparingly
Use named returns only when they materially improve clarity — chiefly to modify a result in a `defer` (e.g. wrapping an error, committing/rolling back a tx). Avoid naked `return`.
- **Reason:** Named returns add hidden state; their one clear win is `defer`-based error decoration. `nonamedreturns` is intentionally disabled to allow this narrow use.

```go
func (r *Repo) Tx(ctx context.Context, fn func(Repo) error) (err error) {
    tx, err := r.db.BeginTxx(ctx, nil)
    if err != nil {
        return fmt.Errorf("begin: %w", err)
    }
    defer func() {
        if err != nil {
            _ = tx.Rollback()
            return
        }
        err = tx.Commit()
    }()
    return fn(newTxRepo(tx))
}
```

## Functional Options for Optional Config
For constructors with many optional settings, use the functional-options pattern instead of a giant parameter list or a config struct with ambiguous zero values.
- **Reason:** Call sites stay readable, defaults live in one place, and adding an option is backward-compatible.

```go
type Option func(*Server)

func WithTimeout(d time.Duration) Option { return func(s *Server) { s.timeout = d } }
func WithLogger(l *slog.Logger) Option   { return func(s *Server) { s.log = l } }

func NewServer(addr string, opts ...Option) *Server {
    s := &Server{addr: addr, timeout: 30 * time.Second, log: slog.Default()}
    for _, opt := range opts {
        opt(s)
    }
    return s
}
```

## Keep Functions Short and Single-Purpose
Prefer functions that do one thing. `funlen`/`gocyclo`/`gocognit` flag overgrown functions; extract helpers next to their single caller.
- **Reason:** Short functions are testable and readable. Extraction also makes the `t.Parallel` unit obvious (see `testing/parallel.md`).

## Pointer vs Value Receivers — Be Consistent
If any method needs a pointer receiver (mutation, large struct), make **all** methods of that type use pointer receivers.
- **Reason:** A mixed method set is confusing and can break interface satisfaction for the value type.

```go
// Good — all pointer receivers
func (s *Service) Do() {}
func (s *Service) Name() string { return s.name }
```

## Avoid Boolean Parameters That Change Behavior
A `func Render(x, true)` is unreadable at the call site. Split into two functions or use a named option type.
- **Reason:** The boolean's meaning is invisible without opening the signature.
