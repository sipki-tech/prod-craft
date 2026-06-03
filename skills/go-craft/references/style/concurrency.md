# Concurrency in Go

Go's concurrency model is powerful but prone to leaks and races if used incorrectly.

## Goroutine Ownership and Lifecycle
Never start a goroutine without knowing exactly how and when it will stop.
- **Reason:** Unstoppable goroutines lead to memory leaks and can leave connections or resources open indefinitely.

```go
// Good — goroutine with explicit stop via context
func worker(ctx context.Context, ch <-chan int) {
    for {
        select {
        case <-ctx.Done():
            return
        case val := <-ch:
            process(val)
        }
    }
}

// Bad — no shutdown path
func worker(ch chan int) {
    for val := range ch {
        process(val)
    }
}
```

## Recover Panics in Spawned Goroutines
A panic in a goroutine that nothing recovers crashes the **entire process** — there's no caller up the stack to catch it (unlike a panic inside an HTTP/gRPC handler, which the framework's recovery middleware catches). Any long-lived goroutine you start with a bare `go f()` needs its own recovery.
- **Reason:** One unhandled panic in a background worker takes down every other in-flight request in the process. Recover, log with the stack, then decide whether to restart the loop or signal shutdown.

```go
// Good — a helper that confines a panic to its own goroutine
func safeGo(ctx context.Context, fn func()) {
    go func() {
        defer func() {
            if r := recover(); r != nil {
                logger.FromContext(ctx).Error("goroutine panic",
                    slog.Any("panic", r), slog.String("stack", string(debug.Stack())))
            }
        }()
        fn()
    }()
}

// Bad — a panic here kills the whole service
go pollQueue(ctx)
```
`errgroup.Go` does **not** recover panics either — wrap the body if the work can panic. Don't use `recover` to mask bugs: log it, surface it, and fix the cause. See `style/errors.md` on when `panic` is acceptable.

## Parallel Service Runner Pattern
Use `errgroup.WithContext` to run multiple services (gRPC, HTTP, metrics, Telegram) in parallel. If any service fails, the group's context cancels all others.
- **Reason:** Ensures clean, coordinated shutdown. No service is left running after an error.

```go
// Good — real pattern from production
func Start(ctx context.Context, services ...func(context.Context) error) error {
    g, groupCtx := errgroup.WithContext(ctx)
    for i := range services {
        g.Go(func() error { return services[i](groupCtx) })
    }
    return g.Wait()
}

// Usage in main.go
serve.Start(ctx,
    serve.GRPC(log, host, grpcPort, grpcServer),
    serve.GRPCGateWay(log, host, gwPort, gwCfg),
    serve.HTTP(log, host, filePort, httpHandler),
    serve.Telegram(log, tgBot),
)
```

## Force Shutdown with Timeout
Combine `signal.NotifyContext` with a background goroutine that force-kills the process after a delay if graceful shutdown stalls.
- **Reason:** Prevents the process from hanging indefinitely if a service refuses to stop.

```go
// Good
func main() {
    ctx, cancel := signal.NotifyContext(context.Background(),
        syscall.SIGHUP, syscall.SIGINT, syscall.SIGQUIT, syscall.SIGTERM)
    defer cancel()
    go forceShutdown(ctx)

    if err := start(ctx, cfgFile, appName); err != nil {
        os.Exit(2)
    }
}

func forceShutdown(ctx context.Context) {
    const shutdownDelay = 15 * time.Second
    <-ctx.Done()
    time.Sleep(shutdownDelay)
    os.Exit(2)
}
```

## Channel Direction in Signatures
Always specify channel direction in function signatures if the function only sends or only receives.
- **Reason:** Prevents accidental sends on a receive-only channel at compile time and clearly signals intent.

```go
// Good
func producer(out chan<- int) { ... }
func consumer(in <-chan int) { ... }

// Bad
func producer(ch chan int) { ... }
```

## `context.Context` Propagation
Always pass `context.Context` as the first argument. Never store a Context inside a struct.
- **Reason:** Context is request-scoped, while structs are often application-scoped. Storing context leads to expired contexts being reused.

```go
// Good
func (s *Service) DoWork(ctx context.Context, id int) error { ... }

// Bad
type Service struct {
    ctx context.Context // Never do this
}
```

## Mutex Usage and Naming
Name your `sync.Mutex` variable `mu`. Place it immediately above the fields it protects. Do NOT embed it.
- **Reason:** Embedding a Mutex exposes `Lock()` and `Unlock()` to the public API of the struct.

```go
// Good
type Cache struct {
    mu    sync.Mutex
    items map[string]string
}

// Bad
type Cache struct {
    sync.Mutex
    items map[string]string
}
```

## Bounded Worker Pool
When fanning out work, cap concurrency with `errgroup.SetLimit`. Unbounded goroutines exhaust DB connections, file descriptors, and memory.
- **Reason:** A pool sized to the limiting resource (DB pool, CPU) gives predictable load and natural backpressure.

```go
g, ctx := errgroup.WithContext(ctx)
g.SetLimit(runtime.GOMAXPROCS(0))
for _, item := range items {
    item := item
    g.Go(func() error { return process(ctx, item) })
}
if err := g.Wait(); err != nil {
    return fmt.Errorf("process: %w", err)
}
```

## Never `time.Sleep` to Synchronize
Coordinate with channels, `sync.WaitGroup`, or `context` cancellation — never by sleeping. In tests, poll with `require.Eventually`.
- **Reason:** Sleeps are flaky (too short races, too long stalls) and mask the real synchronization bug.

## Data Race Detection
Always run tests with the `-race` flag. Never skip it in CI.
```bash
gotestsum --format pkgname -- -race -count=1 ./...
```
