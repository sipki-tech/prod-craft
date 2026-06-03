# proto3 JSON Mapping

Protobuf has a canonical JSON encoding used by the gateway and any JSON client. Know its rules so REST consumers and gRPC clients agree on the wire shape.

## Field names become lowerCamelCase
proto3 JSON renders `lower_snake_case` fields as `lowerCamelCase` by default; parsers also accept the original name.
- **Reason:** This is the canonical mapping, so REST clients see `displayName`, not `display_name`. Keep proto fields `lower_snake_case` and let the mapping derive JSON casing. See [`../style/naming.md`](../style/naming.md).

```proto
message User {
  string display_name = 1; // JSON: "displayName"
}
```

## `json_name` overrides — treat changes as breaking
You can pin a JSON key with `json_name`, but changing it (or renaming the field) breaks JSON clients.
- **Reason:** REST consumers key on the JSON name; altering it is a breaking change even though gRPC binary traffic is unaffected. See [`../schema/compatibility.md`](../schema/compatibility.md).

```proto
message LegacyUser {
  string display_name = 1 [json_name = "name"]; // pinned; do not change later
}
```

## Enums serialize as their value names
proto3 JSON encodes enums as the string value name (e.g. `"USER_STATUS_ACTIVE"`); the integer is also accepted on input.
- **Reason:** String names make JSON self-describing and stable across reordering; this is why the `*_UNSPECIFIED`/prefix naming matters on the wire too. See [`../style/enums.md`](../style/enums.md).

```json
{ "status": "USER_STATUS_ACTIVE" }
```

## 64-bit integers are strings in JSON
`int64`, `uint64`, `fixed64`, and `sfixed64` are encoded as JSON **strings**.
- **Reason:** JSON numbers are IEEE-754 doubles and lose precision above 2^53; quoting 64-bit ints preserves exact values. Clients must parse them as strings. See [`../style/fields.md`](../style/fields.md).

```json
{ "id": "9007199254740993", "createdAtUnixNanos": "1717171717000000000" }
```

## Well-known types have special JSON forms
WKTs serialize to idiomatic JSON, not nested objects: `Timestamp` → RFC 3339 string, `Duration` → `"3.5s"`, `FieldMask` → comma-joined camelCase paths, `Struct` → a plain JSON object.
- **Reason:** These forms are what REST clients expect and what `Struct`/`Value` round-trip as raw JSON. See [`../style/well-known-types.md`](../style/well-known-types.md).

```json
{
  "createdAt": "2026-01-15T09:30:00Z",
  "ttl": "3600s",
  "updateMask": "displayName,locale"
}
```

## Default values are omitted unless you opt in
By default, implicit-presence fields at their zero value are omitted from JSON output; enable "emit defaults" when clients need every key present.
- **Reason:** Omitting defaults keeps payloads small, but a client expecting `"isActive": false` to always appear must opt into emitting defaults. See [`../schema/presence-and-defaults.md`](../schema/presence-and-defaults.md).

```text
// Default:        { "id": "u1" }                       (display_name == "" omitted)
// Emit-defaults:  { "id": "u1", "displayName": "", "status": "USER_STATUS_UNSPECIFIED" }
```

## Checklist
- [ ] Fields stay `lower_snake_case`; JSON camelCase is derived.
- [ ] `json_name` changes/renames treated as breaking for REST.
- [ ] Enums understood to serialize as string value names.
- [ ] 64-bit integers parsed/encoded as JSON strings.
- [ ] WKTs use their special JSON forms (RFC 3339, `"3.5s"`, mask paths).
- [ ] Emit-defaults behavior chosen deliberately for clients.
