# Observability (Logs, Traces, Metrics, Profiles)

Instrument once, correlate everywhere. Structured logs, OpenTelemetry traces, Prometheus metrics, and continuous profiles should all join on the same identifiers so you can pivot between them.

## Structured Logging with `slog`
Use the standard `log/slog` with a JSON handler. Propagate the logger via `context.Context` and use **typed keys**, never ad-hoc strings.
- **Reason:** JSON logs are machine-parseable; context propagation carries request-scoped fields (trace IDs); typed keys prevent `"user_id"` vs `"userId"` drift. See `toolkit/dev.md` for the keys + context helpers.

```go
logger.FromContext(ctx).Info("user created",
    slog.String(logger.UserID.String(), id.String()),
)
```

Never log secrets or PII (tokens, passwords, emails, full request bodies). Log IDs and the fact of the event. See `security/security.md`.

## Tracing with OpenTelemetry
One tracer per package, obtained once in the constructor. Name spans by layer and method.
- **Reason:** A per-call `otel.Tracer(...)` is wasteful; consistent names make traces queryable.

| Layer | Span name | Source |
|---|---|---|
| Transport (gRPC) | `pkg.Service/Method` | `otelgrpc` interceptor |
| Transport (HTTP) | `METHOD /route` | `otelhttp` middleware |
| Application | `App.<Method>` | tracing decorator (`architecture/decorator.md`) |
| Repository (tx) | `Repo.<Method>` | manual span |
| Repository (non-tx) | query span | `otelsql` (don't double-instrument) |

```go
ctx, span := t.tracer.Start(ctx, "App.CreateUser")
defer span.End()
```

## Record Errors as Two Calls
On a real error, record it **and** set the status; skip both for expected sentinels that are normal flow.
- **Reason:** `RecordError` adds the event; `SetStatus` marks the span failed for sampling/alerting. An expected `ErrNotFound` during a probe is not a failure.

```go
if err != nil && !errors.Is(err, app.ErrNotFound) {
    span.RecordError(err)
    span.SetStatus(codes.Error, err.Error())
}
```

## Span Attributes: IDs Yes, PII No
Attach `user_id`, `file_id`, `oauth_provider`; never email, token, or body. Reuse the same key names as your log fields.
- **Reason:** Shared keys are what let Grafana jump log↔trace. PII in spans is a leak that's hard to scrub later.

## Wire the Standard Interceptors
`otelgrpc` (gRPC), `otelhttp` (HTTP), `otelsql` (Postgres) give you transport and query spans for free. Add manual spans only where they're missing.
- **Reason:** Auto-instrumentation is consistent and correct; manual spans around already-instrumented calls double-count.

## Metrics (Prometheus)
Expose `/metrics`. Track the **RED** signals per endpoint: Rate, Errors, Duration (a histogram). Use exemplars to link a metric bucket to a trace.
- **Reason:** RED covers most "is the service healthy" questions; histograms give latency percentiles; exemplars bridge to traces.

```go
reqDuration := prometheus.NewHistogramVec(prometheus.HistogramOpts{
    Name:    "rpc_duration_seconds",
    Buckets: prometheus.DefBuckets,
}, []string{"method", "code"})
```

## Continuous Profiling
Run `net/http/pprof` (guarded, not public) and/or a continuous profiler (Pyroscope) keyed by `service.name`.
- **Reason:** Profiles answer "where is CPU/alloc going" in production without a repro.

## Correlation
Logs emitted within an active span carry `trace_id`/`span_id`; metrics carry exemplars; profiles share `service.name`. Configure the log datasource to derive a trace link.
- **Reason:** The whole point of observability is pivoting from a symptom (slow metric) to a cause (specific trace, then the log line, then the profile).

## Keep Instrumentation Out of Business Logic
Tracing belongs in a decorator and interceptors, not sprinkled through use cases. See `architecture/decorator.md` and `recipes/middleware.md`.
