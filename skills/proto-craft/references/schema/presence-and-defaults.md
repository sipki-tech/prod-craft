# Presence and Defaults

proto3 has two presence modes and no custom defaults. Knowing which mode a field uses determines whether you can tell "unset" from "zero".

## Implicit presence: zero == unset
A plain proto3 scalar has *implicit* presence: the zero value (`0`, `""`, `false`) is indistinguishable from "never set", and is not sent on the wire.
- **Reason:** This keeps messages compact, but means you cannot detect whether a client explicitly sent `0`. Use it only when zero and unset mean the same thing.

```proto
message SearchRequest {
  // limit == 0 is treated as "use the default limit"; unset and 0 are the same.
  int32 limit = 1;
}
```

## Explicit presence: add `optional`
Add `optional` (or use a message field) when "unset" must differ from the zero value. It generates a `has_*` accessor.
- **Reason:** Patch/update flows and tri-state flags need to distinguish "set to false/0" from "not provided". `optional` restores that distinction. See [`../style/fields.md`](../style/fields.md).

```proto
message UpdateSettingsRequest {
  optional bool marketing_opt_in = 1; // false vs not-provided
  optional int32 daily_limit = 2;      // 0 vs not-provided
}
```

## Message and `oneof` fields always have presence
A singular message field and a `oneof` member always track presence (`has_*`), regardless of `optional`.
- **Reason:** A message is a pointer-like value: its absence is distinct from an empty message. This is why wrapping a scalar in a message historically gave presence — now prefer `optional` (see [`../style/well-known-types.md`](../style/well-known-types.md)).

```proto
message GetProfileResponse {
  // Absent profile (not found yet) is distinct from an empty Profile{}.
  Profile profile = 1;
}
```

## No custom default values in proto3
proto3 does not allow declaring a custom default; the default is always the type's zero. Document and apply non-zero defaults in application logic, not the schema.
- **Reason:** Removing proto2's `[default = ...]` keeps the wire format uniform (defaults are never transmitted). Encode "if unset, use N" as a documented server rule. See [`../style/comments.md`](../style/comments.md).

```proto
message ListUsersRequest {
  // page_size: if 0, the server applies a default of 50 (max 100).
  int32 page_size = 1;
}
```

## Absence on the wire and in JSON
Unset implicit-presence fields are omitted from the wire and (by default) from proto3 JSON. Explicit `optional` fields and message fields serialize their presence.
- **Reason:** Consumers must not assume a missing JSON key means an error; it usually means the default. Control whether defaults are emitted via the JSON option (see [`../integration/json-mapping.md`](../integration/json-mapping.md)).

## Use `FieldMask` for "which fields to write"
For partial updates, carry a `google.protobuf.FieldMask` rather than inferring intent from zero values.
- **Reason:** The mask states exactly which fields the caller wants written, cleanly separating "set to empty" from "leave unchanged" without relying on presence tricks. See [`../api/rpc-patterns.md`](../api/rpc-patterns.md).

```proto
import "google/protobuf/field_mask.proto";

message UpdateUserRequest {
  User user = 1;
  google.protobuf.FieldMask update_mask = 2;
}
```

## Checklist
- [ ] Implicit presence used only where zero == unset.
- [ ] `optional` added where unset must differ from zero.
- [ ] No reliance on custom proto-level defaults (they don't exist).
- [ ] Server-side defaults documented in field comments.
- [ ] Partial updates use a `FieldMask`, not zero-value inference.
