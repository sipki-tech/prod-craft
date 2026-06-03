# Streaming

gRPC offers four call types. Default to unary; choose a streaming mode only when its specific shape is justified.

## Unary by default
Use unary RPCs (one request, one response) for CRUD-shaped operations.
- **Reason:** Unary is the simplest to retry, cache, load-balance, and proxy through a gateway; streaming complicates all of these and should earn its place. See [`rpc-patterns.md`](./rpc-patterns.md).

```proto
rpc GetUser(GetUserRequest) returns (GetUserResponse);
```

## Server streaming for server-pushed sequences
Use server streaming when the server emits many messages over time for one request (live updates, progress, tailing).
- **Reason:** A stream avoids polling and delivers items as they occur, but the client cannot page or skip — only use it for genuinely push-shaped data.

```proto
rpc WatchUserEvents(WatchUserEventsRequest) returns (stream UserEvent);
```

## Client streaming for incremental uploads
Use client streaming when the client sends many messages and the server replies once (chunked upload, metric ingestion).
- **Reason:** It bounds memory by processing chunks as they arrive instead of buffering one huge message, but loses per-item acknowledgement — accept that trade-off deliberately.

```proto
rpc ImportUsers(stream ImportUsersRequest) returns (ImportUsersResponse);
```

## Bidirectional streaming, rarely
Use bidi streaming only for genuinely interactive, long-lived sessions (chat, real-time sync).
- **Reason:** Bidi is the hardest to reason about, scale, and recover from failure; most "real-time" needs are met by server streaming or polling. Reserve it for true duplex interaction.

```proto
rpc Chat(stream ChatMessage) returns (stream ChatMessage);
```

## Prefer pagination over streaming for lists
For finite, queryable collections, return a paged list, not a stream.
- **Reason:** Pagination is resumable, cacheable, and gateway-friendly; a stream of list items cannot be resumed from the middle and bypasses standard cursor tooling. See [`pagination.md`](./pagination.md).

```proto
// Prefer this:
rpc ListUsers(ListUsersRequest) returns (ListUsersResponse);
// Over: rpc ListUsers(ListUsersRequest) returns (stream User);
```

## Always propagate deadlines and handle cancellation
Every streaming RPC must respect the call deadline and stop work when the context is cancelled.
- **Reason:** A stream with no deadline leaks goroutines/connections when a client disappears; honoring cancellation frees resources promptly. Bound long streams with a server-side timeout.

```proto
// Document the expected lifetime/deadline of long-lived streams in comments.
// rpc WatchUserEvents: server closes the stream after 30m idle.
```

## Checklist
- [ ] Unary chosen unless a streaming shape is specifically justified.
- [ ] Server streaming used for push sequences; client streaming for uploads.
- [ ] Bidi reserved for true interactive sessions.
- [ ] Finite lists use pagination, not a stream.
- [ ] Deadlines propagated and cancellation handled on every stream.
