# Comments

A `.proto` is documentation as much as a contract. Comments flow into generated code and OpenAPI, so write them for the consumer who never reads the source.

## Document every message, field, service, and RPC
Put a leading `//` comment on every declared symbol.
- **Reason:** These comments are extracted into generated code docstrings and the OpenAPI/Swagger output (see [`../integration/grpc-gateway.md`](../integration/grpc-gateway.md)); an undocumented field becomes an undocumented client API. Lint can require comments on public symbols.

```proto
// UserService manages user accounts and their lifecycle.
service UserService {
  // GetUser returns a single user by id.
  rpc GetUser(GetUserRequest) returns (GetUserResponse);
}

// User is a registered account.
message User {
  // id is the server-assigned unique identifier (UUID v4).
  string id = 1;
}
```

## State units, ranges, and invariants
When a field has a unit, allowed range, or format, say so in the comment.
- **Reason:** The type `int32` does not tell a client whether `timeout` is seconds or millis; the comment is the only place that contract lives (aside from `protovalidate`, see [`../integration/protovalidate.md`](../integration/protovalidate.md)).

```proto
message RetryPolicy {
  // max_attempts is the total number of tries, including the first. Range: 1–10.
  int32 max_attempts = 1;
  // backoff is the base delay between attempts. Must be > 0.
  google.protobuf.Duration backoff = 2;
}
```

## Explain the "why", not the obvious "what"
Comment intent and constraints, not the syntax. Skip comments that merely restate the field name.
- **Reason:** `// the user's email` on `string email` is noise; `// email is normalized to lowercase before storage` is contract a consumer cannot infer.

```proto
message User {
  // email is unique and stored lowercased; login is case-insensitive.
  string email = 2;
}
```

## Mark deprecation with the option AND a comment
Deprecate a field or RPC with `[deprecated = true]` (or `option deprecated = true;` for an RPC) and a comment pointing to the replacement.
- **Reason:** The option makes generated code emit deprecation warnings; the comment tells the human what to use instead and when it will be removed. See [`../schema/evolution.md`](../schema/evolution.md).

```proto
message User {
  // Deprecated: use `display_name` (since v1.4); removed in v2.
  string full_name = 5 [deprecated = true];
  string display_name = 6;
}
```

## Comment `reserved` ranges with the reason
When you reserve a number/name, leave a short note on what used to live there.
- **Reason:** A bare `reserved 4;` is a mystery a year later; `reserved 4; // was phone_number, removed v1.3` preserves history for the next maintainer. See [`fields.md`](./fields.md).

```proto
message User {
  reserved 4; // was phone_number, removed in v1.3 (PII minimization)
}
```

## Checklist
- [ ] Every message, field, service, and RPC has a leading comment.
- [ ] Units, ranges, and formats are stated where relevant.
- [ ] Comments explain intent/invariants, not the obvious.
- [ ] Deprecations use the option plus a "use X instead" note.
- [ ] `reserved` declarations note what they replaced.
