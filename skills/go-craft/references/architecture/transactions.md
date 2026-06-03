# Transactions

Expose transactions as a **closure** on the repository, keep the transactional and non-transactional repos symmetric, and never do external I/O inside a transaction.

## The `Tx(ctx, func(Repo) error)` Closure Pattern
The app layer requests a transaction by passing a function. The repo opens the tx, runs the closure against a transactional repo, and commits or rolls back. The app never touches `*sql.Tx`.
- **Reason:** The transaction boundary lives in the adapter (where it belongs), while the business steps stay in the app layer and remain testable with a mock that just invokes the closure.

```go
// app/contracts.go
type Repo interface {
    // Tx runs fn inside a transaction; commits on nil, rolls back otherwise.
    // Errors: unknown.
    Tx(ctx context.Context, fn func(Repo) error) error
    UserSave(ctx context.Context, u User) (uuid.UUID, error)
    SaveTask(ctx context.Context, t Task) (uuid.UUID, error)
}

// app/handlers.go — business steps grouped atomically
func (a *App) CreateUser(ctx context.Context, email, pass string) (uuid.UUID, error) {
    var id uuid.UUID
    err := a.repo.Tx(ctx, func(r Repo) error {
        var err error
        if id, err = r.UserSave(ctx, User{Email: email}); err != nil {
            return err
        }
        _, err = r.SaveTask(ctx, Task{Kind: TaskSendVerifyEmail, UserID: id})
        return err
    })
    if err != nil {
        return uuid.Nil, fmt.Errorf("a.repo.Tx: %w", err)
    }
    return id, nil
}
```

## Repo ↔ txRepo Symmetry
The non-transactional `Repo` and the transactional `txRepo` implement the **same** interface. Only `Repo.Tx` begins a transaction; `txRepo.Tx` panics.
- **Reason:** Symmetry lets the same business method run with or without an ambient transaction. A nested `Tx` is a programmer error, so it panics loudly rather than silently opening a savepoint.

```go
func (r *Repo) Tx(ctx context.Context, fn func(app.Repo) error) (err error) {
    tx, err := r.db.BeginTxx(ctx, &sql.TxOptions{Isolation: sql.LevelSerializable})
    if err != nil {
        return fmt.Errorf("begin: %w", err)
    }
    defer func() {
        if p := recover(); p != nil {
            _ = tx.Rollback()
            panic(p) // re-panic after cleanup
        }
        if err != nil {
            _ = tx.Rollback()
            return
        }
        err = tx.Commit()
    }()
    return fn(newTxRepo(tx))
}

func (t *txRepo) Tx(context.Context, func(app.Repo) error) error {
    panic("nested transaction") // symmetry: method exists, but nesting is a bug
}
```

## Commit/Rollback via `defer` + Named Return
Use a named `err` return so the deferred function can decide commit vs rollback, and recover from panics to avoid leaking the connection. See `style/functions.md`.

## Serializable Isolation → Retry on Conflict
If you use serializable isolation, expect occasional serialization failures (`SQLSTATE 40001`) and retry the whole closure a bounded number of times.
- **Reason:** Serializable gives correctness for read-then-write flows; the cost is retryable conflicts. Retry only works if the closure is idempotent.

```go
const maxRetries = 3
for attempt := 0; ; attempt++ {
    err := r.Tx(ctx, fn)
    if err == nil || !isSerializationFailure(err) || attempt >= maxRetries {
        return err
    }
}
```

## No External I/O Inside a Transaction
Do not call other adapters (HTTP, email, S3, another DB) from inside `Tx`. Fetch first, mutate in the tx, do side effects after commit.
- **Reason:** External calls hold the transaction (and its locks) open for unbounded time, and they can't be rolled back. Persist an intent row and process it after commit — see `recipes/background-jobs.md`.

## Keep Transactions Short
Read what you need, mutate, commit. Long transactions block vacuum and increase deadlock/serialization-failure rates. See `data/database.md`.
