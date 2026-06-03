# Health & Readiness Checks

Two distinct probes with different jobs. Conflating them makes traffic hit a process that can't serve, or restarts a process that is merely busy.

## Liveness vs Readiness
| Probe | Question | Failure action | Cost |
|---|---|---|---|
| **Liveness** (`/healthz`) | Is the process alive (not deadlocked)? | orchestrator **restarts** it | trivial — no dependency calls |
| **Readiness** (`/readyz`) | Can it serve traffic right now? | load balancer **stops routing** (no restart) | checks dependencies |

- **Rule:** liveness must NOT check dependencies. If liveness pings the DB, a brief DB blip restarts every instance — turning a small outage into a cascade.
- **Rule:** readiness checks the dependencies the request path actually needs (DB, cache, required upstreams).

## Liveness: keep it trivial
```go
mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) {
    w.WriteHeader(http.StatusOK)
})
```
If this handler runs, the process and its HTTP loop are alive. That is all liveness should assert.

## Readiness: check dependencies in parallel, with a deadline
Model each dependency as a small checker; run them concurrently and bound the total time.
```go
type Checker interface {
    Name() string
    Check(ctx context.Context) error
}

func readyHandler(checkers []Checker) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
        defer cancel()

        g, ctx := errgroup.WithContext(ctx)
        for _, c := range checkers {
            c := c
            g.Go(func() error {
                if err := c.Check(ctx); err != nil {
                    return fmt.Errorf("%s: %w", c.Name(), err)
                }
                return nil
            })
        }
        if err := g.Wait(); err != nil {
            http.Error(w, err.Error(), http.StatusServiceUnavailable)
            return
        }
        w.WriteHeader(http.StatusOK)
    }
}
```
A DB checker is just `db.PingContext(ctx)`; a Redis checker is a `PING`. Keep checks cheap and read-only.

## Readiness Drains First on Shutdown
On `SIGTERM`, flip readiness to **failing immediately**, keep serving in-flight requests, then exit. The load balancer sees `/readyz` fail and stops sending new traffic before you close connections — no dropped requests. Ties into [`graceful-shutdown.md`](./graceful-shutdown.md).
```go
var draining atomic.Bool

// in /readyz: refuse as soon as draining starts
if draining.Load() {
    http.Error(w, "draining", http.StatusServiceUnavailable)
    return
}

// on shutdown signal:
draining.Store(true)
time.Sleep(drainDelay) // give load balancers time to notice before servers stop
// ... then graceful server.Shutdown(ctx)
```

## Startup vs Readiness
If a process needs slow warm-up (cache priming, schema checks), separate "started" from "ready": don't report ready until warm-up finishes. Some orchestrators have a dedicated startup probe; otherwise gate readiness behind a `started` flag.

## Where to Expose
- Put probes on the **operational** port/mux (next to metrics), not the public API surface.
- Keep them **unauthenticated** but cheap and information-light — don't leak dependency hostnames or versions.
- Build the checkers in the composition root ([`../architecture/wiring.md`](../architecture/wiring.md)) from the same handles you injected into adapters.

## Checklist
- [ ] Liveness is dependency-free and trivial.
- [ ] Readiness checks request-path dependencies, in parallel, with a timeout.
- [ ] Readiness fails immediately on shutdown, before servers stop.
- [ ] Probes live on the ops port, unauthenticated, low-information.
- [ ] Slow warm-up gated behind readiness (or a startup probe).
