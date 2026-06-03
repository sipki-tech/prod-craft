# Messaging & Consistency

Reliable delivery of events/side effects **without** distributed transactions: **Outbox** (producer), **Inbox / idempotent consumer** (consumer), **Saga** (multi-step workflows with compensation), plus a pragmatic "patterns we avoid" box.

Cross-references: [`transactions.md`](./transactions.md) for the `Tx` closure, [`../recipes/background-jobs.md`](../recipes/background-jobs.md) for the worker loop, [`../data/caching.md`](../data/caching.md) for leader election.

## The Dual-Write Problem
You change the DB **and** must tell the outside world (publish an event, call an API, send mail). Two independent writes are unsafe: a crash in between leaves you inconsistent — DB updated but event lost, or event sent but DB rolled back.

- **Rule:** never do dual writes. Make the side effect either part of the same transaction (outbox row) or fully driven by it.

## Outbox (producer side)
Write the domain change **and** an `outbox` row in the **same transaction**. A separate dispatcher reads unpublished rows and delivers them. Delivery is at-least-once.

```sql
CREATE TABLE outbox (
    id           uuid PRIMARY KEY,
    aggregate_id uuid        NOT NULL,
    topic        text        NOT NULL,
    payload      jsonb       NOT NULL,
    created_at   timestamptz NOT NULL DEFAULT now(),
    published_at timestamptz
);
CREATE INDEX outbox_unpublished_idx ON outbox (created_at) WHERE published_at IS NULL;
```

```go
// The business change and the outbox row commit atomically.
err := repo.Tx(ctx, func(r app.Repo) error {
    if err := r.OrderMarkPaid(ctx, orderID); err != nil {
        return err
    }
    return r.OutboxAdd(ctx, app.OutboxMsg{
        ID:          ids.New(),
        AggregateID: orderID,
        Topic:       "order.paid",
        Payload:     payload, // self-contained snapshot
    })
})
```

Dispatcher (leader-only — see `background-jobs.md`):

```go
// Claim a batch without blocking other workers.
rows, err := r.OutboxClaimUnpublished(ctx, batchSize) // SELECT ... WHERE published_at IS NULL
                                                      // ORDER BY created_at LIMIT n FOR UPDATE SKIP LOCKED
for _, m := range rows {
    if err := publisher.Publish(ctx, m); err != nil {
        continue // leave row; retry next tick with backoff
    }
    _ = r.OutboxMarkPublished(ctx, m.ID)
}
```

- **Atomic:** the outbox write shares the business transaction.
- **Self-contained payload:** snapshot the data; don't re-read mutable state at publish time.
- **Single publisher per row:** leader election or `FOR UPDATE SKIP LOCKED`.
- **Stable id:** carry the message id downstream so consumers can dedup.

## Inbox / Idempotent Consumer (consumer side)
At-least-once delivery means duplicates. The inbox dedups by message id **before** applying effects, giving "effect exactly once".

```sql
CREATE TABLE inbox (
    message_id uuid PRIMARY KEY,
    handled_at timestamptz NOT NULL DEFAULT now()
);
```

```go
err := repo.Tx(ctx, func(r app.Repo) error {
    inserted, err := r.InboxClaim(ctx, msg.ID) // INSERT ... ON CONFLICT DO NOTHING
    if err != nil {
        return err
    }
    if !inserted {
        return nil // duplicate: skip side effects
    }
    return applyEffect(ctx, r, msg) // same tx as the claim
})
```

- **Claim + effect in one transaction:** no partial apply.
- **Dedup key:** the producer's stable id (from the outbox).
- **Prefer naturally idempotent handlers** (upserts) where you can.

## Outbox + Inbox = Effect-Once
Outbox guarantees the event is eventually published; inbox guarantees it is applied once. Together you get practical exactly-once **effects** over at-least-once **delivery** — no 2PC/XA.

## Saga (multi-step workflows)
For a workflow spanning several steps or services, model it as a sequence of local transactions, each with a **compensating** action to undo it.

- **Choreography:** each step emits an event (via outbox) that triggers the next. Decoupled; the whole flow is harder to see.
- **Orchestration:** a coordinator (process manager) drives steps and issues compensations on failure. Centralized; easier to reason about; more coupling.

Rules:

- **Local commits:** each step commits independently; no global lock.
- **Compensation per step:** every forward action needs an undo (refund, release, cancel).
- **Persist saga state** (current step + status) so it survives restarts.
- **Idempotent compensations:** they may be retried.

## Eventual Consistency
Consumers see changes after a delay. Design for it:

- **Tolerate staleness** on reads; surface "pending" states in the UI.
- **Keep hard invariants inside a single aggregate/transaction** — don't bolt synchronous cross-aggregate invariants onto async flows.
- **Make operations idempotent** so retries are safe.

## Patterns We Avoid (unless there is a strong reason)
- **Distributed transactions (2PC/XA):** operationally fragile; replace with outbox/inbox/saga.
- **CQRS:** separate read/write models add real cost. Use only for genuine read/write asymmetry, not by default.
- **Event Sourcing:** powerful but heavy (versioning, replay, snapshots). Default to state-stored + outbox.
- **Premature broker/microservices:** start with a DB-backed outbox table; introduce Kafka/NATS only when volume or decoupling demands it. The publisher interface stays the same, so the migration is local.

## Checklist
- [ ] No dual writes — side effects go through the outbox or run inside the tx.
- [ ] Outbox row written in the **same** tx as the business change.
- [ ] Dispatcher is leader-only or uses `FOR UPDATE SKIP LOCKED`.
- [ ] Messages carry a stable id; consumers dedup via the inbox.
- [ ] Inbox claim + effect share one transaction.
- [ ] Saga steps have idempotent compensations and persisted state.
