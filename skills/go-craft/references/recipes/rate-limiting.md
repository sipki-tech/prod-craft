# Inbound Rate Limiting & Throttling

Protecting your service from being overwhelmed or abused by limiting how often a caller may hit it. Distinct from the *client-side* limiter in [`outbound-http.md`](./outbound-http.md) (which respects *upstream* quotas) and from brute-force lockout in [`../security/auth.md`](../security/auth.md).

## Pick the Key First
A limit is always per **key**. Choose deliberately:
- **Per IP** — coarse DoS protection; beware shared NATs and spoofable `X-Forwarded-For` (trust it only behind your own proxy).
- **Per authenticated user / API key** — fair-use enforcement.
- **Per route + key** — expensive endpoints get tighter limits.
- **Global** — a blunt safety cap for a whole dependency.

## Token Bucket (single instance)
`golang.org/x/time/rate` gives a token bucket: a sustained `rate` plus a `burst`. Keep one limiter per key in a bounded, expiring map.
```go
limiter := rate.NewLimiter(rate.Limit(10), 20) // 10 rps, burst 20
if !limiter.Allow() {
    // reject — see response shape below
}
```

## As HTTP Middleware
```go
func RateLimit(limiterFor func(key string) *rate.Limiter) Middleware {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            if !limiterFor(clientKey(r)).Allow() {
                w.Header().Set("Retry-After", "1")
                http.Error(w, "rate limit exceeded", http.StatusTooManyRequests)
                return
            }
            next.ServeHTTP(w, r)
        })
    }
}
```
For gRPC, do the same in an interceptor and return `codes.ResourceExhausted` (see [`middleware.md`](./middleware.md), [`grpc-api.md`](./grpc-api.md)).

## Respond Correctly
- **HTTP:** `429 Too Many Requests` + `Retry-After`. Optionally `RateLimit-Limit` / `RateLimit-Remaining` headers.
- **gRPC:** `codes.ResourceExhausted`.
- **Never** block the inbound request goroutine indefinitely waiting for a token — reject fast. (`limiter.Wait` is for *outbound* calls you control.)

## Distributed Limiting (multiple instances)
A per-instance limiter lets `N` replicas allow `N×` the intended rate. For a global limit, keep the counter in Redis. A fixed-window counter is simple and atomic:
```go
// key like "rl:user:42:1700000000" (window bucketed by unix seconds)
count, err := redis.Incr(ctx, key)
if err != nil {
    return err // fail-open or fail-closed — decide explicitly (see below)
}
if count == 1 {
    _ = redis.Expire(ctx, key, window)
}
if count > limit {
    return ErrRateLimited
}
```
- Make the increment-and-expire atomic with a **Lua script** (or a pipelined `INCR`+`EXPIRE`). See [`../data/caching.md`](../data/caching.md).
- Fixed windows allow up to 2× burst at boundaries; use a **sliding window** or a token-bucket-in-Lua if that matters.
- **Decide fail-open vs fail-closed** when Redis is unavailable: availability versus protection. Make it a conscious choice.

## Bound the Limiter Map
Per-key `*rate.Limiter`s leak memory if never evicted. Cap the map and expire idle entries (LRU or a TTL sweep), or use a library that does.

## Layering
- A **coarse edge limit** at the proxy/gateway (cheap, protects everything).
- **Fine-grained business limits** in the app (per-user, per-route), where you know identity and cost.
- Rate limiting is a **policy adapter**, not business logic — keep it in transport/middleware, configured from [`config.md`](./config.md).

## Checklist
- [ ] Limit key chosen deliberately (IP / user / route / global).
- [ ] `429` + `Retry-After` (HTTP) or `ResourceExhausted` (gRPC).
- [ ] Inbound path rejects fast, never blocks indefinitely.
- [ ] Distributed limit via Redis when correctness across replicas matters.
- [ ] Fail-open vs fail-closed decided explicitly for the limiter store.
- [ ] Per-key limiter map is bounded/expiring.
