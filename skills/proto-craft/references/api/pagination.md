# Pagination

List endpoints must page. Use opaque cursor tokens over a stable ordering, not numeric offsets.

## `page_size` + opaque `page_token` → `next_page_token`
A `List` request takes a `page_size` and a `page_token`; the response returns the page plus a `next_page_token`.
- **Reason:** This is the standard, language-agnostic cursor shape (AIP-158). The token is opaque to the client, so the server can change its internals without breaking callers. See [`rpc-patterns.md`](./rpc-patterns.md).

```proto
message ListUsersRequest {
  int32 page_size = 1;   // see bounds below
  string page_token = 2; // opaque; empty on the first page
}
message ListUsersResponse {
  repeated User users = 1;
  string next_page_token = 2; // empty means no more pages
}
```

## Token is opaque, server-encoded
Encode the cursor (e.g. last id + sort key) into a base64 string the client treats as a blob; never document or parse its contents on the client.
- **Reason:** An opaque token lets you switch from keyset to a different strategy without a contract change, and prevents clients from forging cursors that skip server-side filters.

```text
// Server-internal only: base64({"last_id":"...","last_sort_key":"..."})
// Client rule: pass next_page_token back verbatim; never construct it.
```

## Prefer keyset over offset
Page with a `WHERE (sort_key, id) > (:last_sort_key, :last_id)` cursor, not `OFFSET n`.
- **Reason:** Offset pagination skips or duplicates rows when the underlying set changes between pages and degrades as the offset grows; keyset is stable and index-friendly.

```proto
// The opaque page_token encodes the keyset cursor over a stable, indexed order.
// Offset is acceptable only for small, write-quiet, admin-only collections.
```

## Order by a stable, total key
List results in a deterministic order whose key is unique (or tie-broken by `id`).
- **Reason:** Cursors require a total order; ties on a non-unique sort key make pages overlap or drop rows. Tie-break on the primary id.

```proto
message ListUsersRequest {
  int32 page_size = 1;
  string page_token = 2;
  // order_by is optional; the server always tie-breaks on id for a total order.
  string order_by = 3; // e.g. "created_at desc"
}
```

## Bound `page_size` with a documented max
Treat `page_size` as a hint: clamp to a maximum and apply a default when unset/zero.
- **Reason:** Unbounded pages let one client exhaust server memory; a documented default+max keeps responses predictable. Pair with `protovalidate` (see [`../integration/protovalidate.md`](../integration/protovalidate.md)).

```proto
message ListUsersRequest {
  // page_size: default 50, max 100; values above 100 are clamped to 100.
  int32 page_size = 1;
  string page_token = 2;
}
```

## Optionally return a `total_size`
Add a `total_size` only when clients genuinely need a count and it is cheap to compute.
- **Reason:** Exact counts can be expensive on large tables; expose them deliberately (and consider an estimate) rather than by default.

```proto
message ListUsersResponse {
  repeated User users = 1;
  string next_page_token = 2;
  int32 total_size = 3; // optional; may be an estimate
}
```

## Checklist
- [ ] Request has `page_size` + opaque `page_token`; response has `next_page_token`.
- [ ] Token is server-encoded and opaque to clients.
- [ ] Keyset cursor over a stable, total order (tie-broken by id).
- [ ] `page_size` clamped to a documented default and max.
- [ ] Offset only for small, write-quiet collections.
- [ ] `total_size` exposed only when needed and affordable.
