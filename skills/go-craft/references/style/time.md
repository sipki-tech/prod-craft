# Time & Duration

Time bugs are subtle and timezone-dependent. Standardize on UTC, typed durations, and an injectable clock.

## Use `time.Time` and `time.Duration`, Not Integers
Represent instants as `time.Time` and spans as `time.Duration`. Never pass "seconds as int".
- **Reason:** `time.Duration` is self-documenting and type-safe; `ttl int` invites unit confusion.

```go
// Good
func cache(ctx context.Context, key string, ttl time.Duration) error

// Bad
func cache(ctx context.Context, key string, ttlSeconds int) error
```

## Store and Compute in UTC
Convert to UTC at the boundary; keep everything internal in UTC. Persist as `timestamp with time zone` (see `data/migrations.md`).
- **Reason:** Mixing local zones causes off-by-hours bugs and broken comparisons across DST.

```go
now := time.Now().UTC()
```

## Durations as Named Constants
Give meaningful spans names; don't sprinkle magic numbers.
- **Reason:** `sessionTTL` documents intent; `15 * time.Minute` repeated everywhere drifts.

```go
const (
    sessionTTL    = 24 * time.Hour
    requestBudget = 3 * time.Second
)
```

## Inject a Clock for Testability
Business logic that reads "now" takes a `Clock` dependency instead of calling `time.Now()` directly.
- **Reason:** A real `time.Now()` makes tests non-deterministic and forces them to be non-parallel (see `testing/parallel.md`). An injected clock lets tests advance time.

```go
type Clock interface{ Now() time.Time }

type realClock struct{}
func (realClock) Now() time.Time { return time.Now().UTC() }

type fakeClock struct{ t time.Time }
func (f *fakeClock) Now() time.Time       { return f.t }
func (f *fakeClock) Advance(d time.Duration) { f.t = f.t.Add(d) }
```

## Compare with `Equal`, Measure with `Since`/`Until`
Use `t1.Equal(t2)` (handles monotonic/zone), and `time.Since(start)` for elapsed.
- **Reason:** `==` on `time.Time` compares wall-clock + monotonic + location and can surprise you.

```go
start := time.Now()
// ...work...
elapsed := time.Since(start) // not time.Now().Sub(start)
```

## Always `Stop` Timers/Tickers
`time.Ticker` and `time.Timer` must be stopped to release resources, typically via `defer`.

```go
t := time.NewTicker(time.Second)
defer t.Stop()
```

## Never `time.Sleep` to Coordinate
Synchronize with channels/`context`, and in tests poll with `require.Eventually` (see `style/concurrency.md`).
