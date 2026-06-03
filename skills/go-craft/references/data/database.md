# Database Access (PostgreSQL)

Use the repository pattern over `database/sql` (with the `pgx` driver and `sqlx` for scanning). Keep SQL explicit, parameterized, and converted to domain types at the boundary.

## Stack
- Driver: `pgx` via `database/sql`, wrapped with `otelsql` for query spans (see `toolkit/observability.md`).
- Scanning: `sqlx` (`GetContext`, `SelectContext`).
- Dynamic queries: `squirrel` with `PlaceholderFormat(sq.Dollar)`.
- **Reason:** This combo gives connection pooling, tracing, ergonomic struct scanning, and safe dynamic SQL without an ORM hiding the queries.

## Always Parameterize
Use `$1, $2, ...` placeholders. Never `fmt.Sprintf` user data into SQL.
- **Reason:** String-built SQL is the #1 injection vector (see `security/security.md`). Parameters are also plan-cacheable.

```go
// Good
const queryUserByEmail = `select id, email, status from users where email = $1`
err := db.GetContext(ctx, &row, queryUserByEmail, email)

// Forbidden
q := fmt.Sprintf("select ... where email = '%s'", email)
```

## Spell Out Columns; No `SELECT *`
List columns explicitly in hot-path queries.
- **Reason:** Stabilizes the scan target and the query plan, and makes adding a column safe.

## Static Query Is a `const`; Dynamic Uses Squirrel
Static SQL lives in a `const query = ...`. Build variable filters/sorts with squirrel.
- **Reason:** Constants are greppable and reviewable; squirrel keeps dynamic SQL parameterized.

```go
q := sq.Select("id", "email", "status").From("users").
    Where(sq.Eq{"status": dom.UserStatusDefault}).
    OrderBy("created_at desc").Limit(uint64(limit)).
    PlaceholderFormat(sq.Dollar)
sql, args, err := q.ToSql()
```

## Scan Into Row Models, Convert to Domain
Scan into a `userRow` with `db:` tags, then convert to `app.User`. Never scan into a domain entity.
- **Reason:** Decouples schema from domain and keeps tags off domain types (see `architecture/domain-modeling.md`).

```go
type userRow struct {
    ID     uuid.UUID `db:"id"`
    Email  string    `db:"email"`
    Status uint8     `db:"status"`
}
func (r userRow) toDomain() *app.User { /* ... */ }
```

## Convert Driver Errors to Domain Sentinels
Map `sql.ErrNoRows` → `app.ErrNotFound`, unique violations → `app.ErrEmailExist`, etc., in a per-adapter `convertErr`. Never leak `*pgconn.PgError`.
- **Reason:** Upholds the dependency rule; the app routes on `app.Err*` (see `style/errors.md`).

## Connection Pool
Configure the pool explicitly and probe with `PingContext` (with retry) on startup.
- **Reason:** Defaults are rarely right for production; a startup ping fails fast on a bad DSN (see `recipes/config.md`).

```go
db.SetMaxOpenConns(50)
db.SetMaxIdleConns(50)
db.SetConnMaxLifetime(60 * time.Second)
db.SetConnMaxIdleTime(10 * time.Second)
```

## Transactions via the Closure Pattern
Group read-then-write steps with `Repo.Tx(ctx, func(Repo) error)`. Keep transactions short; no external I/O inside. Full pattern, isolation, and retry: `architecture/transactions.md`.

## Avoid N+1
Don't query per item in a loop. Fetch in one round trip with `WHERE id = ANY($1)` or a join.
- **Reason:** N+1 multiplies latency by N and saturates the pool.

```go
// Bad
for _, id := range ids { u, _ := r.UserByID(ctx, id) }

// Good
users, _ := r.UsersByIDs(ctx, ids) // WHERE id = ANY($1)
```

## Always Pass `ctx` and a `LIMIT`
Every query takes `ctx` (for cancellation/tracing); any query that can return many rows has a `LIMIT`.
- **Reason:** Cancellation frees connections; an unbounded result set can OOM the service.

## Read Plans with `EXPLAIN (ANALYZE, BUFFERS)`
For any query touching a large table, check the plan. A `Seq Scan` returning few rows means a missing index; pick the index type deliberately (btree default, gin for jsonb/arrays, partial for skewed predicates). See `data/migrations.md`.
