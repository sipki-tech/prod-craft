# Fields

Field numbers are the permanent wire identity of your data. Choose types deliberately and never disturb existing numbers.

## Field numbers 1–15 cost one byte
Numbers 1–15 use a single byte for the tag; 16–2047 use two. Reserve the low numbers for the most frequently set fields.
- **Reason:** The tag is encoded on every message on the wire; spending one-byte tags on hot fields measurably shrinks payloads. Leave a few low numbers free for future hot fields.

```proto
message User {
  string id = 1;            // hot: always present
  string email = 2;         // hot
  string display_name = 3;  // hot
  // ... reserve 4–15 for future frequent fields ...
  string locale = 16;       // cold: two-byte tag is fine
}
```

## Never renumber or reuse a field number
A field number is fixed for life. Never change a field's number, and never assign an old number to a new field.
- **Reason:** Wire data is keyed by number, not name. Reusing a number makes new readers misinterpret old bytes — silent data corruption, not a clean error. See [`../schema/compatibility.md`](../schema/compatibility.md).

```proto
// Bad — number 2 once meant email; now it means something else
message User {
  string id = 1;
  int64 created_at_unix = 2; // was: string email = 2;  ← corruption
}
```

## `reserved` numbers AND names on delete
When you delete a field, reserve both its number and its name in the same message.
- **Reason:** Reserving the number stops anyone reusing it on the wire; reserving the name stops a future JSON/text-format clash and a confusing recycled identifier. See [`../schema/evolution.md`](../schema/evolution.md).

```proto
message User {
  reserved 4, 7 to 9;
  reserved "phone_number", "legacy_role";

  string id = 1;
  string email = 2;
}
```

## Choose scalar types deliberately
Match the type to the data and its growth. Use `sint32`/`sint64` for values that are frequently negative, fixed-width types for hashes/IDs that are uniformly large, and `bytes` for opaque binary.
- **Reason:** `int32`/`int64` use varint encoding that is large for negative numbers; `sint*` uses zig-zag and is compact for signed values; `fixed*` is smaller than varint when values are usually big. Picking wrong wastes bytes on every message.

```proto
message Measurement {
  sint64 temperature_delta = 1; // often negative → zig-zag
  fixed64 content_hash = 2;     // uniformly large → fixed is smaller
  bytes raw_payload = 3;        // opaque binary, not string
}
```

## `repeated` is ordered; use `map` for keyed lookups
Use `repeated` for ordered lists; use `map<K, V>` for associative data instead of a `repeated` list of key/value pairs.
- **Reason:** `map` documents intent and generates idiomatic dictionaries. Note `map` fields cannot be `repeated` and have unspecified ordering on the wire. Scalar `repeated` numeric fields are packed by default in proto3 (compact).

```proto
message Document {
  repeated string tags = 1;            // ordered list
  map<string, string> attributes = 2;  // keyed lookups
}
```

## Explicit presence with `optional`
In proto3, add the `optional` keyword when you must distinguish "unset" from the zero value for a scalar.
- **Reason:** Without `optional`, a proto3 scalar has *implicit* presence: `0`, `""`, and `false` are indistinguishable from unset. `optional` generates a `has_*` accessor. See [`../schema/presence-and-defaults.md`](../schema/presence-and-defaults.md).

```proto
message UpdateSettings {
  optional bool marketing_opt_in = 1; // distinguish false from unset
  optional int32 retry_limit = 2;      // distinguish 0 from unset
}
```

## Checklist
- [ ] Hot fields occupy numbers 1–15; some low numbers left free.
- [ ] No existing field number changed or reused.
- [ ] Deleted fields have both number and name `reserved`.
- [ ] Scalar types chosen for the data's sign/size (`sint*`, `fixed*`, `bytes`).
- [ ] `map` used for keyed data; `repeated` for ordered lists.
- [ ] `optional` used where unset must differ from zero.
