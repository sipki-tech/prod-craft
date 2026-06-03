# Well-Known Types

Google ships standard types for time, partial updates, and dynamic data. Use them instead of reinventing — they have defined JSON forms and cross-language support.

## `Timestamp` and `Duration`, not raw integers
Use `google.protobuf.Timestamp` for instants and `google.protobuf.Duration` for spans, not `int64` epoch fields.
- **Reason:** WKTs carry their semantics, render as RFC 3339 / `"3.5s"` in JSON (see [`../integration/json-mapping.md`](../integration/json-mapping.md)), and remove "is this seconds or millis?" ambiguity. Document the timezone expectation (typically UTC).

```proto
import "google/protobuf/timestamp.proto";
import "google/protobuf/duration.proto";

message Session {
  google.protobuf.Timestamp created_at = 1; // UTC
  google.protobuf.Duration ttl = 2;
}
```

## `FieldMask` for partial updates
Use `google.protobuf.FieldMask` to express which fields an update touches.
- **Reason:** Without a mask, an update cannot tell "set this field to empty" from "leave it unchanged". The mask lists exactly the fields to write. See [`../api/rpc-patterns.md`](../api/rpc-patterns.md) and [`../schema/presence-and-defaults.md`](../schema/presence-and-defaults.md).

```proto
import "google/protobuf/field_mask.proto";

message UpdateUserRequest {
  User user = 1;
  google.protobuf.FieldMask update_mask = 2; // e.g. paths: ["display_name","locale"]
}
```

## `Struct` and `Value` for dynamic data
Use `google.protobuf.Struct` / `Value` / `ListValue` for genuinely schemaless data (arbitrary JSON).
- **Reason:** They map directly to JSON objects/values and are the right tool when the shape is unknown at design time — but prefer concrete fields whenever the shape *is* known, since `Struct` loses type safety and validation.

```proto
import "google/protobuf/struct.proto";

message WebhookEvent {
  string type = 1;
  google.protobuf.Struct payload = 2; // provider-defined, schemaless
}
```

## `Any` is a last resort
Reach for `google.protobuf.Any` only when a field must hold *one of an open, unbounded* set of message types. Prefer a `oneof` of known types first.
- **Reason:** `Any` defers type safety to runtime, complicates clients (they must know the URL→type map), and weakens lint/breaking analysis. A `oneof` keeps the set explicit and checked. See [`../schema/messages.md`](../schema/messages.md).

```proto
import "google/protobuf/any.proto";

message AuditRecord {
  string action = 1;
  google.protobuf.Any detail = 2; // only if detail types are open-ended
}
```

## Wrappers are mostly legacy
`google.protobuf.StringValue`, `Int32Value`, etc. exist to give scalars explicit presence. In modern proto3, prefer the `optional` keyword instead.
- **Reason:** `optional` is simpler, generates `has_*` accessors, and avoids boxing every value in a message. Use wrappers only for compatibility with an API that already exposes them. See [`fields.md`](./fields.md).

```proto
// Prefer this
message Patch { optional int32 retry_limit = 1; }

// Over the legacy wrapper
// import "google/protobuf/wrappers.proto";
// message Patch { google.protobuf.Int32Value retry_limit = 1; }
```

## Avoid `Empty` — return a named message
Do not use `google.protobuf.Empty` as an RPC response. Return a named `XResponse`, even if empty today.
- **Reason:** An empty named message can grow fields additively; `Empty` cannot, forcing a breaking signature change the first time you need to return anything. See [`../api/services.md`](../api/services.md).

```proto
// Good — can add fields later without breaking
message DeleteUserResponse {}
rpc DeleteUser(DeleteUserRequest) returns (DeleteUserResponse);
```

## Checklist
- [ ] Time uses `Timestamp`/`Duration`, not epoch integers; timezone documented.
- [ ] Partial updates carry a `FieldMask`.
- [ ] `Struct`/`Value` only for truly schemaless data.
- [ ] `Any` avoided in favor of `oneof` unless the type set is open-ended.
- [ ] `optional` preferred over wrapper types.
- [ ] RPCs return named `XResponse`, never `Empty`.
