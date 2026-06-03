# Database Migrations

Schema changes are versioned, immutable, and forward-only in production. Plan changes so they never lock a busy table or break a running deploy.

## Sequential, Immutable Files
One change per numbered file with `up`/`down` sections. Once a migration has been applied anywhere, **never edit it** — fix forward with a new migration.
- **Reason:** Editing an applied migration desyncs environments that already ran the old version. Sequential numbering gives a deterministic order.

```sql
-- cmd/app/migrate/2.verification_tokens.sql
-- up
create table verification_tokens (
    token      uuid primary key default gen_random_uuid(),
    user_id    uuid not null references users (id) on delete cascade,
    expires_at timestamp with time zone not null
);

-- down
drop table verification_tokens;
```

## Type Choices
| Need | Use | Avoid |
|---|---|---|
| Timestamp | `timestamp with time zone` | bare `timestamp` |
| Primary key | `uuid default gen_random_uuid()` | `serial`/`bigserial` |
| Money | `numeric(p, s)` | `float`/`double precision` |
| Free text | `text` | `varchar(n)` |
| Structured blob | `jsonb` | `json` |
| Multi-value | `text[]` + gin index | comma-separated string |

- **Reason:** These defaults avoid timezone bugs, key exhaustion, float rounding, and arbitrary length limits.

## Declare Constraints and FK Actions Explicitly
Name unique constraints (so the app can map their violations to sentinels — see `data/database.md`) and always specify `on delete`.
- **Reason:** A named constraint (`users_email_key`) is what `convertErr` matches; implicit FK behavior surprises people.

## Indexes
- `btree` (default) for equality/range — auto-created on `primary key`/`unique`.
- `gin` for `jsonb` containment and array membership.
- `partial` (`where status = 'active'`) when most rows are excluded by a constant predicate.
- `expression` (`lower(email)`) when you filter on a function.

Build indexes on hot tables with `create index concurrently`, **in their own migration**.
- **Reason:** `create index concurrently` cannot run inside a transaction; mixing it with other DDL breaks the runner and risks a long lock.

```sql
-- up  (own migration, no other statements)
create index concurrently idx_users_lower_email on users (lower(email));
```

## Bound Lock and Statement Time
Set conservative timeouts so a migration fails fast instead of blocking production.
- **Reason:** A migration waiting on a lock can stall every write to the table.

```sql
set lock_timeout = '3s';
set statement_timeout = '60s';
```

## Zero-Downtime: Expand → Migrate → Contract
Any change that would otherwise require an exclusive lock or a backfill ships in three separate migrations/deploys:
1. **Expand** — add the new column nullable (with a default); app writes both old and new.
2. **Migrate** — backfill the new column in batches; switch reads to it.
3. **Contract** — add `not null`, drop the old column.

- **Reason:** Each phase is independently deployable and reversible, so the app and schema are never incompatible at any instant.

## Backfill in Batches with a Cursor
Backfill large tables in chunks keyed by primary key, not one giant `UPDATE`.
- **Reason:** A single `UPDATE` over millions of rows takes a long lock and bloats WAL.

```sql
update users set tier = 'free'
where id in (select id from users where tier is null order by id limit 5000);
-- repeat until 0 rows affected
```

## Coordinate Migrations with Deploys
Migrations are backward-compatible with the currently running app version (expand before deploy, contract after). Running migrations at startup is fine for a single-writer/leader; for multiple replicas, run them as a gated step. See `architecture/wiring.md`.
