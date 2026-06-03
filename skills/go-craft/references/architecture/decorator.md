# Decorator Pattern (Interface Wrappers)

Add cross-cutting behavior — tracing, caching, metrics, retry, logging — by **wrapping an interface**, not by editing the implementation. The wrapper implements the same interface and delegates to the inner value. *Wrap, don't pollute.*

## The Shape
A decorator holds the wrapped interface plus its extra dependency, implements every method, does its cross-cutting work, and delegates.
- **Reason:** Business logic stays free of observability/caching concerns; you can stack, reorder, or remove a concern without touching the core.

```go
type Service interface {
    CreateUser(ctx context.Context, email string) (uuid.UUID, error)
}

// tracing decorator
type tracedService struct {
    next   Service
    tracer trace.Tracer
}

func NewTraced(next Service) *tracedService {
    return &tracedService{next: next, tracer: otel.Tracer("app")}
}

func (t *tracedService) CreateUser(ctx context.Context, email string) (uuid.UUID, error) {
    ctx, span := t.tracer.Start(ctx, "App.CreateUser")
    defer span.End()
    return t.next.CreateUser(ctx, email) // delegate, unchanged
}
```

## Rule: A Decorator Is Pure Pass-Through
A decorator contains **no business logic and no decision-making** beyond its single concern. It must not change the result or swallow errors.
- **Reason:** If a wrapper alters behavior, callers can no longer reason about the inner type. Keep `//nolint:wrapcheck` on a pure pass-through tracer since it propagates errors verbatim.

## Mirror the Interface 1:1
Every method on the wrapped interface gets a wrapper method. Adding a method to the interface means adding it to each decorator.
- **Reason:** A missing method silently falls back to... nothing — it won't compile, which is the point. Use a compile-time assertion: `var _ Service = (*tracedService)(nil)`.

## Caching Decorator (cache-aside)
A `cachedRepo` wraps `Repo`, serving reads from cache and invalidating on writes. The underlying `Repo` knows nothing about Redis.

```go
type cachedRepo struct {
    next  app.Repo
    cache Cache
}

func (c *cachedRepo) UserByID(ctx context.Context, id uuid.UUID) (*app.User, error) {
    if u, ok := c.cache.getUser(ctx, id); ok {
        return u, nil
    }
    u, err := c.next.UserByID(ctx, id)
    if err != nil {
        return nil, err
    }
    c.cache.setUser(ctx, u, cacheTTL)
    return u, nil
}

func (c *cachedRepo) UserSave(ctx context.Context, u app.User) (uuid.UUID, error) {
    id, err := c.next.UserSave(ctx, u)
    if err == nil {
        c.cache.delUser(ctx, id) // invalidate on write
    }
    return id, err
}
```

See `data/caching.md` for cache-aside details and key naming.

## Composition Order Matters
Wrap from the inside out. Outer wrappers run first on the way in.
- **Reason:** You almost always want tracing/metrics on the *outside* (measuring the whole call, including cache hits) and caching closer to the core.

```go
// inner -> outer
var repo app.Repo = postgresRepo
repo = newCachedRepo(repo, cache)   // cache wraps postgres
repo = newMeteredRepo(repo, reg)    // metrics wrap cache+postgres

var svc Service = app.New(repo, ...)
svc = NewTraced(svc)                // tracing is outermost
```

## When to Use a Decorator vs. Middleware
Decorators wrap **domain interfaces** (`Repo`, `Service`); middleware/interceptors wrap **transport** (`http.Handler`, gRPC interceptor — see `recipes/middleware.md`). Same idea, different layer. Tracing typically appears in both: once at the transport edge, once around the app via the decorator.
