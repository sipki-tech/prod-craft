# Graceful Shutdown

Servers must shut down gracefully when receiving termination signals. Terminating immediately drops active connections and corrupts data in flight.

## Recipe: Multi-Service Graceful Shutdown

**Problem:** You have multiple servers (gRPC, REST gateway, HTTP, Telegram, metrics) that must all start in parallel and shut down cleanly.
**Solution:** Combine `signal.NotifyContext` + `errgroup` + a force-kill goroutine.

```go
package main

import (
    "context"
    "log/slog"
    "os"
    "os/signal"
    "syscall"
    "time"

    "golang.org/x/sync/errgroup"
)

const exitCode = 2

func main() {
    log := buildLogger(slog.LevelDebug)

    ctx, cancel := signal.NotifyContext(context.Background(),
        syscall.SIGHUP, syscall.SIGINT, syscall.SIGQUIT, syscall.SIGTERM)
    defer cancel()
    go forceShutdown(ctx)

    if err := start(ctx); err != nil {
        log.Error("shutdown", slog.String("err", err.Error()))
        os.Exit(exitCode)
    }
}

// forceShutdown kills the process if graceful shutdown stalls.
func forceShutdown(ctx context.Context) {
    const shutdownDelay = 15 * time.Second
    <-ctx.Done()
    time.Sleep(shutdownDelay)
    os.Exit(exitCode)
}
```

- **Reason:** `signal.NotifyContext` provides a clean cancellation path. The `forceShutdown` goroutine is a safety net: if the app takes more than 15 seconds to shut down, it force-kills the process.

## `serve.Start` Pattern

Use a central `serve.Start` function that runs all services in parallel via `errgroup`. If any service fails, all others are cancelled.

```go
// internal/serve/serve.go
func Start(ctx context.Context, services ...func(context.Context) error) error {
    g, groupCtx := errgroup.WithContext(ctx)
    for i := range services {
        g.Go(func() error { return services[i](groupCtx) })
    }
    return g.Wait()
}

// Usage in main.go
serve.Start(ctx,
    serve.Metrics(log, host, metricsPort, reg),
    serve.GRPC(log, host, grpcPort, grpcServer),
    serve.GRPCGateWay(log, host, gwPort, gwCfg),
    serve.HTTP(log, host, filePort, httpHandler, "file-server"),
    serve.Telegram(log, tgBot),
)
```

- **Reason:** Single entry point for all services. No manual goroutine management. `errgroup` cancels the group context on first error, triggering shutdown of all other services through `groupCtx`.
