# Context Usage

`context.Context` carries deadlines, cancellation, and request-scoped values across API boundaries. Threading it correctly is the backbone of clean shutdown and tracing.

## `ctx` Is Always the First Parameter
Pass `context.Context` as the first argument to every function that does I/O, blocks, or calls another such function. Name it `ctx`.
- **Reason:** A consistent position lets callers and linters (`contextcheck`, `revive`) verify propagation mechanically.

```go
// Good
func (a *App) UserByID(ctx context.Context, id uuid.UUID) (*User, error)

// Bad
func (a *App) UserByID(id uuid.UUID, ctx context.Context) (*User, error)
```

## Never Store `ctx` in a Struct
A context is request-scoped; a struct is usually application-scoped. Storing it freezes one request's deadline into shared state.
- **Reason:** A stored context expires and is then reused by unrelated calls, causing spurious cancellations.

```go
// Bad
type Service struct {
    ctx context.Context // never
}

// Good — pass it per call
func (s *Service) Do(ctx context.Context) error { ... }
```

## No `context.Background()` in Business Code
Only `main`, tests, and the top of a detached background job create a root context. Everywhere else, propagate the caller's `ctx`.
- **Reason:** Creating a fresh root detaches the call from the request's trace and cancellation, producing orphan spans and goroutine leaks.

```go
// Bad — inside a handler/usecase
rows, err := s.repo.List(context.Background(), filter)

// Good
rows, err := s.repo.List(ctx, filter)
```

## Propagate `ctx` Into Goroutines
A goroutine started inside a request must capture the request's `ctx`, not a new one, and must stop when it is cancelled.
- **Reason:** Otherwise the goroutine outlives the request and loses its trace parent.

```go
// Good
g, ctx := errgroup.WithContext(ctx)
g.Go(func() error { return fetch(ctx) }) // captures ctx

// Bad — detached, leaks past the request
go func() { fetch(context.Background()) }()
```

## Set Deadlines for Outbound I/O
Wrap external calls (HTTP to a third party, slow queries) with a timeout derived from the inbound deadline.
- **Reason:** A handler with no downstream deadline can wedge a connection forever.

```go
ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
defer cancel()
resp, err := client.Do(req.WithContext(ctx))
```

## `context.WithValue` Is for Request-Scoped Cross-Cutting Data Only
Use it for the logger, the trace span, the authenticated session — never for optional function parameters. Always use an **unexported key type**.
- **Reason:** A string key collides across packages; passing real arguments via context hides the function's true signature.

```go
// Good
type ctxKey struct{}
func NewContext(ctx context.Context, l *slog.Logger) context.Context {
    return context.WithValue(ctx, ctxKey{}, l)
}

// Bad — optional arg smuggled through context
ctx = context.WithValue(ctx, "limit", 50)
```

## Check Cancellation in Long Loops
In CPU-bound or long-running loops, periodically honor cancellation.

```go
for _, batch := range batches {
    if err := ctx.Err(); err != nil {
        return err // ctx cancelled / deadline exceeded
    }
    process(ctx, batch)
}
```

See `style/concurrency.md` for goroutine lifecycle and `recipes/middleware.md` for putting the session into the context at the transport edge.
