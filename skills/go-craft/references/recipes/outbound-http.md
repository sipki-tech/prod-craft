# Outbound HTTP & Resilience

Calling third-party APIs, webhooks, and downloading remote files. The network is hostile: everything times out, fails, and lies about sizes. Treat every outbound call as unreliable and wrap it in an adapter.

## Always Configure the Client
The zero-value `http.Client` has **no timeout** — one hung connection leaks a goroutine forever. Never use `http.DefaultClient` for outbound calls. Build an explicit client and **reuse** it (it pools connections):

```go
client := &http.Client{
    Timeout: 10 * time.Second, // whole-request ceiling
    Transport: &http.Transport{
        MaxIdleConns:        100,
        MaxIdleConnsPerHost: 10,
        IdleConnTimeout:     90 * time.Second,
        TLSHandshakeTimeout: 5 * time.Second,
    },
}
```

## Always Pass Context
Use `http.NewRequestWithContext` so the caller's deadline/cancellation propagates and the request aborts when the caller gives up.

```go
req, err := http.NewRequestWithContext(ctx, http.MethodGet, uri, body)
```

## Bound the Response Body
Don't trust `Content-Length`; a malicious or buggy server can omit or lie about it. Cap the bytes you actually read with `io.LimitReader`:

```go
const maxBody = 25 << 20 // 25 MiB
data, err := io.ReadAll(io.LimitReader(resp.Body, maxBody+1))
if err != nil {
    return fmt.Errorf("read body: %w", err)
}
if len(data) > maxBody {
    return ErrFileTooLarge
}
```

Always close the body in a `defer` (the read above drains it for connection reuse).

## Check Status Explicitly
A non-2xx response is **not** a transport error — `err` is `nil`. Inspect `resp.StatusCode` and decide what's retryable (`5xx`, `429`) versus fatal (`4xx`).

## Retries with Backoff + Jitter
Retry only **idempotent** and **transient** failures (timeouts, `5xx`, `429`). Use exponential backoff with jitter, a capped attempt count, and respect `ctx`:

```go
func do(ctx context.Context, f func() error) error {
    const maxAttempts = 4
    back := 100 * time.Millisecond
    for attempt := 0; ; attempt++ {
        err := f()
        if err == nil || !retryable(err) || attempt == maxAttempts-1 {
            return err
        }
        jitter := time.Duration(rand.Int63n(int64(back)))
        select {
        case <-time.After(back + jitter):
        case <-ctx.Done():
            return ctx.Err()
        }
        back *= 2
    }
}
```

Honor `Retry-After` on `429`/`503` when present. Never retry non-idempotent POSTs unless you send an idempotency key.

## Idempotency Keys
For outbound **writes**, send a stable `Idempotency-Key` header so a retry doesn't double-charge or double-create. Reuse the same key across retries of the same logical operation.

## Circuit Breaker & Bulkhead
- **Circuit breaker:** after N consecutive failures, open the circuit and fail fast for a cool-down window instead of hammering a dead dependency; go half-open to probe recovery.
- **Bulkhead:** cap concurrency per dependency (bounded worker pool / semaphore) so one slow upstream can't exhaust all your goroutines and connections.

## SSRF: Guard User-Supplied URLs
If the URL comes from a user (webhooks, "import from URL", avatar-by-link), an attacker can point it at internal services (`169.254.169.254`, `10.0.0.0/8`, `localhost`). Defend:

- **Allowlist schemes** (`http`/`https` only) and, ideally, hosts.
- **Resolve the host and reject private/loopback/link-local IPs** before connecting.
- **Disable or tightly limit redirects** and re-validate each hop.
- **Short timeout + body size cap** (above).

```go
client.CheckRedirect = func(req *http.Request, via []*http.Request) error {
    if len(via) >= 3 {
        return errors.New("too many redirects")
    }
    return validateHost(req.URL.Host) // re-check the resolved IP each hop
}
```

## Rate-Limit Your Own Calls
Respect upstream quotas with a client-side limiter (`golang.org/x/time/rate`); block on `Wait(ctx)` before sending. This is the pattern an email-sending adapter uses — a `*rate.Limiter` field and a `Wait` before each provider call:

```go
if err := c.limiter.Wait(ctx); err != nil {
    return fmt.Errorf("limiter wait: %w", err)
}
// ... perform the provider request
```

## Wrap It in an Adapter
Keep all of this behind an app-layer interface (`Downloader`, `EmailSender`, `PaymentGateway`). The app calls the interface; the adapter owns timeouts, retries, breaker, and SSRF. Business logic stays clean and the policy stays testable.

## Checklist
- [ ] Explicit client with `Timeout` + tuned `Transport`; reused, not per-call.
- [ ] Context passed to every request.
- [ ] Body bounded with `io.LimitReader`; status checked explicitly.
- [ ] Retries only for idempotent + transient failures; backoff + jitter; ctx-aware.
- [ ] Idempotency key on outbound writes.
- [ ] Circuit breaker + concurrency cap per dependency.
- [ ] SSRF guard for user-supplied URLs (private-IP block + redirect control).
- [ ] Client-side rate limiting to respect upstream quotas.
