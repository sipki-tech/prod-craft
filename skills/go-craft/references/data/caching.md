# Caching & Coordination (Redis)

Redis is a cache and a coordination layer, **never the source of truth** (that's Postgres). Namespace every key, set a TTL on everything, and use atomic primitives for anything read-modify-write.

## Cache-Aside via a Decorator
Wrap the repository with a cache decorator: read from cache, fall back to the DB, populate the cache, and invalidate on write. The DB repo knows nothing about Redis. See `architecture/decorator.md`.
- **Reason:** Cache-aside keeps the cache optional and recoverable; the decorator keeps caching out of business logic.

```go
func (c *cachedRepo) UserByID(ctx context.Context, id uuid.UUID) (*app.User, error) {
    if u, ok := c.cache.getUser(ctx, id); ok {
        return u, nil
    }
    u, err := c.next.UserByID(ctx, id)
    if err != nil {
        return nil, err
    }
    c.cache.setUser(ctx, u, cacheTTL) // populate
    return u, nil
}
// On any write: delete the key (invalidate), don't try to update it in place.
```

## Collapse Stampedes with `singleflight`
When a hot key expires, many concurrent requests miss the cache at once and all stampede the DB (a "thundering herd"). `golang.org/x/sync/singleflight` collapses concurrent calls for the same key into a single execution; the rest wait and share the result.
- **Reason:** One slow query under load shouldn't multiply into thousands of identical queries the instant a popular key expires.

```go
var group singleflight.Group

func (c *cachedRepo) UserByID(ctx context.Context, id uuid.UUID) (*app.User, error) {
    if u, ok := c.cache.getUser(ctx, id); ok {
        return u, nil
    }
    v, err, _ := group.Do(id.String(), func() (any, error) { // one DB hit per key
        u, err := c.next.UserByID(ctx, id)
        if err != nil {
            return nil, err
        }
        c.cache.setUser(ctx, u, cacheTTL)
        return u, nil
    })
    if err != nil {
        return nil, err
    }
    return v.(*app.User), nil
}
```
- Call `group.Forget(key)` if a failed call shouldn't be shared by late arrivals.
- `singleflight` dedups **within one process**; pair it with a short TTL (and optionally a per-key Redis lock) to limit cross-replica stampedes.

## Namespace Every Key
Format keys as `app:<class>:<entity>:<id>`. Never use a bare numeric or user-supplied string as a full key.
- **Reason:** Namespacing prevents collisions, enables prefix scans, and keeps PII out of key names (use opaque IDs — see `security/security.md`).

| Use case | Pattern | TTL |
|---|---|---|
| Cache | `app:cache:user:<id>` | 1–5 min |
| Session | `app:sess:<id>` | session lifetime |
| Verification code | `app:verify:<purpose>:<id>` | 5–15 min |
| Idempotency | `app:idem:<scope>:<key>` | 24 h |
| Lock | `app:lock:<resource>` | ≥ 3× critical section |
| Rate limit | `app:rl:<scope>:<id>:<window>` | window size |

## TTL Is Mandatory
Every key gets an expiry. No unbounded keys.
- **Reason:** Without TTL, a cache becomes an unmanaged second database that drifts from the source of truth and grows forever.

## Set Context Deadlines
Pass a `ctx` with a deadline to every Redis call (`go-redis` honors it).
- **Reason:** A request without a deadline can wedge a pooled connection on a slow server.

## Atomicity: `SET NX EX`, then Lua
- Set-if-absent with TTL in one round trip: `SET key val NX EX ttl`.
- Compare-and-delete / compare-and-set / "incr + expire on first write": a Lua script.
- **Reason:** A read-modify-write across two commands is a race; `SETNX` and Lua execute atomically on the server. `MULTI/EXEC` can't branch on intermediate values — Lua can.

```go
ok, err := rdb.SetNX(ctx, key, val, ttl).Result() // atomic acquire
```

## Never `KEYS *`
Use `SCAN` with a `COUNT` hint; delete by prefix with `SCAN` + `UNLINK`.
- **Reason:** `KEYS` blocks the single-threaded server across the whole keyspace; `UNLINK` frees memory asynchronously.

## Distributed Lock / Leader Election
For "exactly one replica runs this loop", acquire `SET key instanceID NX EX ttl`, refresh via heartbeat at `ttl/3`, and release with a Lua compare-and-delete that checks ownership.
- **Reason:** A plain `DEL` can delete *someone else's* lease after a GC pause; the ownership check prevents that. For serializing a DB transaction across processes, prefer a Postgres advisory lock instead. See `recipes/background-jobs.md`.

```go
ok, _ := rdb.SetNX(ctx, "app:leader:jobs", instanceID, leaderTTL).Result()
// if ok: you are leader; refresh at leaderTTL/3; release via Lua check-and-del
```

## Treat Redis as Ephemeral
Assume keys can vanish (eviction, restart). The app must recover by reading Postgres.
- **Reason:** Cache and locks are performance/coordination tools; correctness must not depend on Redis durability.

## Don't Block the Request Path
`BLPOP`/`XREAD BLOCK`/`SUBSCRIBE` belong in background workers, never in a request handler.
