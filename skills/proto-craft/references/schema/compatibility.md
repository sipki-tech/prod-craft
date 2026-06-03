# Wire Compatibility

Compatibility is decided by field **numbers** and **wire types**, never by field names. Memorize what is safe and what corrupts data.

## Safe vs breaking — the table
| Change | Wire-safe? | Notes |
|---|---|---|
| Add a new field with a new number | ✅ | Old readers ignore it; new readers see default when absent. |
| Remove a field (and `reserved` it) | ✅ | Old senders' bytes are ignored; reserve the number+name. |
| Rename a field (same number/type) | ✅ wire / ⚠️ codegen | Bytes unaffected; **breaks** JSON keys and generated code/clients. |
| Change a field's **number** | ❌ | Old and new disagree on identity — silent corruption. |
| Reuse a retired number for a new field | ❌ | New readers parse old bytes as the new field. |
| Change type across wire-compat groups | ❌ | E.g. `string`↔`int32` reinterprets bytes. |
| Add/remove `repeated` on a scalar | ⚠️ | Compatible for packed scalars; risky for `message`/`string`. |
| Move a field into/out of a `oneof` | ❌ | Changes presence semantics and generated unions. |

## Type-compatibility groups
Within a group, changing among the types is wire-compatible (value may truncate); across groups it is not.
- **Reason:** Each group shares a wire representation, so the bytes still decode; crossing groups reinterprets the bytes as a different kind of value. Verify any change with `easyp breaking` (see [`../toolkit/breaking.md`](../toolkit/breaking.md)).

```text
Group A (varint):   int32, int64, uint32, uint64, bool, enum
Group B (varint zz): sint32, sint64
Group C (64-bit):   fixed64, sfixed64
Group D (32-bit):   fixed32, sfixed32
Group E (len-delim): string, bytes        (compatible iff bytes are valid UTF-8)
message ≠ everything else (its own length-delimited shape)
```

## Field numbers are permanent identity
A number, once shipped, is bound to its field forever — across renames, type tweaks, and refactors.
- **Reason:** The encoder writes `(number << 3 | wire_type)` and nothing else identifying the field. Two parties only agree because they agree on the number. See [`../style/fields.md`](../style/fields.md) and [`evolution.md`](./evolution.md).

```proto
// Renaming is wire-safe (same number 2) but breaks JSON + generated code:
message User {
  string email_address = 2; // was: string email = 2;
}
```

## Rename is wire-safe but consumer-breaking
A rename keeps the bytes valid but changes the proto3 JSON key and every generated accessor.
- **Reason:** REST/JSON clients key on the field name (`json_name`), and compiled clients reference the generated symbol; both break on rename even though gRPC binary traffic does not. See [`../integration/json-mapping.md`](../integration/json-mapping.md). Treat a rename like a breaking change for public APIs.

## Enums and `oneof` evolve carefully
Adding an enum value is safe (open enums preserve unknowns); removing one requires `reserved`. Adding a field to an existing `oneof` is **breaking** for presence semantics.
- **Reason:** Consumers branch on the active `oneof` case; a new case can surface as "none of the known ones". Plan `oneof` growth deliberately. See [`../style/enums.md`](../style/enums.md) and [`evolution.md`](./evolution.md).

## Checklist
- [ ] No field number changed or reused.
- [ ] Type changes stay within one wire-compat group.
- [ ] Renames treated as breaking for JSON/codegen consumers.
- [ ] Removed fields/enum values are `reserved`.
- [ ] `oneof` membership changes reviewed as breaking.
- [ ] `easyp breaking` run against the baseline before merge.
