# Background Jobs (Transactional Outbox + Leader Worker)

Deferred side effects (send email, call a third party, emit an event) must survive crashes and never run inside a database transaction. Persist the *intent* atomically with the state change, then process it from a single leader.

## The Problem with Inline Side Effects
Calling an external API inside `Repo.Tx` (see `architecture/transactions.md`) is wrong: the call can't be rolled back, and it holds the transaction (and its locks) open for the duration of a network round trip.
- **Reason:** Atomicity and external I/O are incompatible. The fix is to make the *record of work* transactional and the *work itself* asynchronous.

## Transactional Outbox
In the same transaction that changes state, insert a `task` row describing the side effect. Commit both or neither.
- **Reason:** If the commit succeeds, the task is guaranteed recorded; if it rolls back, no orphan side effect. No lost or phantom work.

```go
err := a.repo.Tx(ctx, func(r app.Repo) error {
    id, err := r.UserSave(ctx, user)
    if err != nil {
        return err
    }
    _, err = r.SaveTask(ctx, app.Task{
        Kind:   app.TaskKindSendVerificationEmail,
        UserID: id,
    })
    return err // user + task commit together
})
```

```sql
create table tasks (
    id          uuid primary key default gen_random_uuid(),
    kind        smallint not null,
    payload     jsonb    not null default '{}',
    created_at  timestamp with time zone not null default now(),
    finished_at timestamp with time zone
);
```

## Leader-Only Worker Loop
Exactly one replica runs the processing loop, guarded by leader election (see `data/caching.md`). It polls unfinished tasks, dispatches by kind, and marks them finished.
- **Reason:** Running the loop on every replica would process each task N times. Leader election makes it singular without a separate scheduler service.

```go
func (a *App) Process(ctx context.Context) error {
    const poll = time.Second
    t := time.NewTicker(poll)
    defer t.Stop()
    for {
        select {
        case <-ctx.Done():
            return ctx.Err()
        case <-t.C:
            if !a.leader.IsLeader(ctx) {
                continue
            }
            if err := a.drainTasks(ctx); err != nil {
                logger.FromContext(ctx).Error("drainTasks", slog.String("err", err.Error()))
            }
        }
    }
}
```

## Dispatch by Kind, Finish on Success
Fetch a batch of unfinished tasks (`order by created_at limit N`), handle each by its `kind`, and call `FinishTask` only after the side effect succeeds. Do the external I/O **outside** any transaction.
- **Reason:** Marking finished before success would drop the work on a crash; doing I/O in a tx reintroduces the original problem.

```go
func (a *App) drainTasks(ctx context.Context) error {
    tasks, err := a.repo.UnfinishedTasks(ctx, batchSize)
    if err != nil {
        return fmt.Errorf("repo.UnfinishedTasks: %w", err)
    }
    for _, task := range tasks {
        switch task.Kind {
        case app.TaskKindSendVerificationEmail:
            if err := a.handleSendVerificationEmail(ctx, task); err != nil {
                continue // leave unfinished; retried next tick
            }
        default:
            return fmt.Errorf("unknown task kind: %d", task.Kind)
        }
        if err := a.repo.FinishTask(ctx, task.ID); err != nil {
            return fmt.Errorf("repo.FinishTask: %w", err)
        }
    }
    return nil
}
```

## Handlers Must Be Idempotent
A task may run more than once (crash after side effect, before `FinishTask`). Make handlers safe to repeat (dedup on the provider side, or check state first).
- **Reason:** At-least-once delivery is the realistic guarantee; idempotency turns duplicates into no-ops.

## Honor Cancellation; Back Off on Failure
The loop exits on `ctx.Done()`; failed tasks are retried on the next tick (optionally with a `attempts`/`next_run_at` column for backoff).
- **Reason:** Clean shutdown (see `architecture/wiring.md`) plus bounded retry avoids hot-looping on a poison task.

## When to Graduate to a Queue
A DB-backed outbox is ideal up to moderate volume. Move to a real broker (with the outbox still as the source of truth) when you need high throughput, fan-out, or cross-service delivery.
