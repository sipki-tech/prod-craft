# Wiring & Composition Root

`main.go` is the **only** place that knows about concrete implementations. It builds the dependency graph, starts services, and tears everything down in order.

## Thin `main`, Real Work in `start`
`main()` parses flags, builds the logger, sets up signal-based cancellation, and calls `start(ctx, ...)`. All wiring lives in `start` and `init*` helpers.
- **Reason:** Keeps the composition root testable and the entry point trivial. See `style/structure.md`.

```go
func main() {
    cfgFile := &flags.File{DefaultPath: "/config.yml"}
    logLevel := &flags.Level{Level: slog.LevelInfo}
    flag.Var(cfgFile, "cfg", "path to config file")
    flag.Var(logLevel, "log_level", "log level")
    flag.Parse()

    log := buildLogger(logLevel.Level)
    ctx, cancel := signal.NotifyContext(context.Background(),
        syscall.SIGINT, syscall.SIGTERM)
    defer cancel()
    go forceShutdown(ctx)

    if err := start(ctx, log, cfgFile); err != nil {
        log.Error("shutdown", slog.String("err", err.Error()))
        os.Exit(2)
    }
}
```

## Constructor Dependency Injection
Wire dependencies by passing interfaces into constructors — no globals, no service locator, no DI framework.
- **Reason:** Explicit constructors make the graph visible and the dependency rule (see `architecture/clean.md`) enforceable. Manual DI is enough for a monolith.

```go
func start(ctx context.Context, log *slog.Logger, cfg config) error {
    infra, cleanup, err := initInfra(ctx, cfg)   // open DB/Redis/S3
    if err != nil {
        return fmt.Errorf("initInfra: %w", err)
    }
    defer cleanup()

    svc := initApp(infra)                         // build adapters + app
    traced := apptracing.New(svc)                 // decorate (see architecture/decorator.md)
    return runServers(ctx, log, cfg, traced)      // serve everything
}
```

## Group Infra Construction; Return One `cleanup`
`initInfra` opens external resources and returns a single `cleanup func()` that closes them in **reverse** (LIFO) order.
- **Reason:** One ordered teardown prevents "closed DB while a query is in flight" and leaked connections.

```go
func initInfra(ctx context.Context, cfg config) (*infra, func(), error) {
    db, err := database.NewSQL(ctx, cfg.DB)
    if err != nil {
        return nil, nil, fmt.Errorf("database.NewSQL: %w", err)
    }
    rdb, err := redis.New(ctx, cfg.Cache)
    if err != nil {
        _ = db.Close()
        return nil, nil, fmt.Errorf("redis.New: %w", err)
    }
    cleanup := func() {
        _ = rdb.Close() // last opened, first closed
        _ = db.Close()
    }
    return &infra{db: db, rdb: rdb}, cleanup, nil
}
```

## Decorate at the Composition Root
Tracing/caching/metrics wrappers are applied here, not inside the layers they wrap. See `architecture/decorator.md`.

## Run Services in Parallel; Cancel Together
Start gRPC, the REST gateway, the HTTP file server, metrics, and any bot via one `errgroup`-based runner. First error cancels the group. See `recipes/graceful-shutdown.md`.

```go
return serve.Start(ctx,
    serve.Metrics(log, addr.metrics, reg),
    serve.GRPC(log, addr.grpc, grpcServer),
    serve.GRPCGateWay(log, addr.gw, gwCfg),
    serve.HTTP(log, addr.files, fileHandler, "file-server"),
)
```

## Leader-Only Background Loops
Work that must run on exactly one replica (a task-processing loop, a scheduler) is started here, guarded by leader election. See `recipes/background-jobs.md` and `data/caching.md`.

## Fail Fast on Misconfiguration
Validate config and probe critical dependencies in `start`; exit immediately if a required URL/secret is missing rather than failing on the first request. See `recipes/config.md`.
