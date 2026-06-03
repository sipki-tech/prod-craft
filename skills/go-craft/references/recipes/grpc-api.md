# gRPC & Gateway API Design

The `.proto` is the contract (see `toolkit/protobuf.md`). This file covers the *design* decisions: method shape, errors, pagination, idempotency, deadlines, and versioning. One app core serves gRPC and a gRPC-Gateway REST proxy from the same definitions.

## Method Naming: Verb + Noun
Methods are imperative: `CreateUser`, `ListSessions`, `RevokeToken`. Plural in `List*`, singular elsewhere.
- **Reason:** Consistent, predictable names map cleanly to REST verbs and read well in clients.

## Unary by Default
Use unary RPCs for CRUD-shaped operations. Reach for streaming only when justified:
- server-streaming for real-time/progress updates;
- client-streaming/bidi rarely;
- large file bytes → a dedicated HTTP endpoint, not gRPC.
- **Reason:** Unary is simplest to operate, cache, and proxy through the gateway and Traefik.

## Error Model: Domain Error → Code + `errdetails`
Map `app.Err*` sentinels to gRPC codes in one interceptor (see `style/errors.md` and `recipes/middleware.md`). Put machine-readable detail in `errdetails`, not the message.
- **Reason:** Clients branch on `code` + structured details, never on human-readable strings.

| Domain situation | gRPC code | `errdetails` |
|---|---|---|
| Validation failure | `INVALID_ARGUMENT` | `BadRequest{field_violations}` |
| Not found | `NOT_FOUND` | `ResourceInfo` |
| Duplicate / conflict | `ALREADY_EXISTS` / `ABORTED` | `ResourceInfo` / `PreconditionFailure` |
| No / invalid token | `UNAUTHENTICATED` | — |
| Forbidden | `PERMISSION_DENIED` | `ErrorInfo{reason}` |
| Rate limit | `RESOURCE_EXHAUSTED` | `QuotaFailure` |
| Bug / unknown | `INTERNAL` | `DebugInfo` (non-prod only) |

## Cursor Pagination by Default
Page with an opaque `page_token`, not an offset, for collections with concurrent writes.
- **Reason:** Offset pagination skips/duplicates rows when the underlying set changes. The token encodes `{last_id, last_sort_key}` (base64) over a stable, indexed sort key (see `data/database.md`).

```proto
message ListUsersRequest {
  int32  page_size  = 1 [(buf.validate.field).int32 = {gte: 0, lte: 100}];
  string page_token = 2; // opaque; empty for first page
}
message ListUsersResponse {
  repeated User  users           = 1;
  string         next_page_token = 2; // empty == end
}
```

Offset is acceptable only for small, admin-only, write-quiet collections.

## Idempotency for Retryable Mutations
Mutating RPCs that clients may retry carry a `request_id` (UUID). The server dedups on `app:idem:<rpc>:<request_id>` for ~24h and replays the original response.
- **Reason:** Network/gateway timeouts cause client retries; without dedup you double-charge/double-create. See `data/caching.md`.

## Propagate Deadlines
Read `ctx.Deadline()` and pass a budgeted deadline to downstream calls; never strip it. A handler with no deadline is a bug.
- **Reason:** Deadlines bound resource use and let the whole call chain fail fast together (see `style/context.md`).

## Validate at the Edge
Declare constraints in the proto (`buf.validate`) and validate once in an interceptor. Don't re-validate deeper.
- **Reason:** Single source of validation truth; the app layer can trust its inputs (see `architecture/domain-modeling.md`).

## Evolve Without Breaking
Additive changes stay in `vN`; breaking changes go to `v(N+1)`. Never renumber or reuse a field number/name — mark removed ones `reserved`. Enums always have an `UNSPECIFIED = 0`.
- **Reason:** Wire compatibility depends on field numbers; `buf breaking` in CI enforces this (see `toolkit/ci.md`).

## Keep HTTP Mapping in the Proto
`google.api.http` annotations live with the RPC so the gateway is generated from the single source of truth. Match verbs to semantics (`POST` create, `PATCH` update, `DELETE` delete, `GET` read).

## Convert Types at the Transport Edge
Handlers translate request → domain, call `app`, translate domain → response. No business logic in handlers, no proto types in `app`. See `architecture/clean.md` and `architecture/domain-modeling.md`.
