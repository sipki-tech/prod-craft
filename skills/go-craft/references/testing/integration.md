# Integration Testing

Integration tests verify behavior against **real** infrastructure (Postgres, Redis, S3-compatible storage) brought up in Docker. They are gated by a build tag and still run in parallel via per-test namespacing.

## Build Tag on Every File
The first line is the tag, followed by a blank line before `package`.
- **Reason:** The `integration` tag keeps these out of the fast unit cycle; they run via `task test-integration`.

```go
//go:build integration

package repo_test
```

## Containers via a `testhelper` Package
Spin up dependencies with a shared helper built on `ory/dockertest` (or `testcontainers-go`). Centralize container setup so every suite uses the same readiness logic.
- **Reason:** One place owns image versions, readiness probes (`pool.Retry` with a real ping), and teardown — tests stay short and consistent.

```go
import (
    "testing"

    "github.com/example/app/internal/testhelper"
    "github.com/stretchr/testify/require"
)
```

## The `start(t)` Pattern
Each adapter package has a `start(t)` in `init_test.go` that:
1. Builds a deadline `ctx` via `testhelper.Context(t)` (e.g. 120s, auto-cancelled in `t.Cleanup`).
2. Builds `require.New(t)`.
3. Allocates a unique namespace via `testhelper.Namespace(t)` (derived from `t.Name()`).
4. Spins up the needed container(s) and constructs the adapter.
5. Registers `t.Cleanup` for `Close()`.
6. Returns `(ctx, *Repo, *require.Assertions)`.

```go
func start(t *testing.T) (context.Context, *repo.Repo, *require.Assertions) {
    t.Helper()
    ctx := testhelper.Context(t)
    assert := require.New(t)

    ns := testhelper.Namespace(t)
    dsn := testhelper.Postgres(ctx, t, assert) // unique DB per test
    r, err := repo.New(ctx, dsn, migrateDir, ns)
    assert.NoError(err)
    t.Cleanup(func() { _ = r.Close() })

    return ctx, r, assert
}
```

## Hard Rules
1. **`//go:build integration`** as the first line of every integration file.
2. **`t.Parallel()` is mandatory** — containers/resources are namespaced per `t.Name()`, so parallel runs don't collide (see `testing/parallel.md`).
3. **`testhelper.Context(t)`**, never `context.Background()` — it carries a deadline and auto-cancels.
4. **Namespace every shared resource** (DB schema, Redis prefix, bucket) by `t.Name()`. Never invent ad-hoc names.
5. **Allocate ports via the helper**, never hardcode — avoids collisions across parallel tests.
6. **`require` for setup/teardown**; `assert` only when you want to keep checking after a failure.
7. **`t.Cleanup` over `defer`** so teardown runs LIFO across `start(t)` and the test body.
8. **No `time.Sleep`** — use container readiness and `require.Eventually` for eventual consistency.
9. **No leaked goroutines** — everything the test starts is cancelled via `ctx` or stopped in `t.Cleanup`.
10. **Migrations run automatically** from the migrate dir; never bake DDL into the test.

## Decision: Unit or Integration?
| Need | Test type |
|---|---|
| Business logic with mocked boundaries | Unit (`testing/unit.md`) |
| Real SQL, constraints, isolation, query plan | Integration (repo) |
| Cache TTL, atomic ops, eviction | Integration (cache) |
| Object-store roundtrip, presigned URLs | Integration (files) |
| Full RPC → DB → tracing wiring | Integration (e2e) |

If the only assertion is "the right method was called with the right args", it's a unit test with gomock.

## Eventual Consistency
For asynchronous effects, poll instead of sleeping.

```go
require.Eventually(t, func() bool {
    got, _ := r.TaskByID(ctx, id)
    return got.FinishedAt != nil
}, 5*time.Second, 50*time.Millisecond)
```

## Running
```bash
task test-integration
# or target one:
go test -tags=integration ./internal/adapters/repo -run TestRepo_Smoke -v
```
