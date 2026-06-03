# Schema Evolution

Schemas live for years. Evolve them additively, retire fields safely, and reserve breaking changes for a new package version.

## Additive-only by default
Grow a schema by adding new fields, messages, enum values, and RPCs — never by mutating existing ones.
- **Reason:** Additive changes are backward- and forward-compatible: old binaries ignore new fields, new binaries read defaults for absent ones. This is the entire reason Protobuf scales across teams. See [`compatibility.md`](./compatibility.md).

```proto
message User {
  string id = 1;
  string email = 2;
  string display_name = 3; // added in v1.2 — safe
}
```

## Reserve on removal, always
Deleting a field or enum value means adding it to `reserved` (number and name) in the same change.
- **Reason:** Reserving prevents a future maintainer from reusing the number (corruption) or the name (JSON/codegen clash). A removal without `reserved` is a latent bug. See [`../style/fields.md`](../style/fields.md).

```proto
message User {
  reserved 5;            // was full_name
  reserved "full_name";
  string id = 1;
  string display_name = 6;
}
```

## Deprecate before you delete
Mark a field/RPC `[deprecated = true]` and document the replacement first; remove it only after consumers migrate.
- **Reason:** A staged deprecation gives clients a compile-time warning and a window to move, turning a hard break into a planned transition. See [`../style/comments.md`](../style/comments.md).

```proto
message User {
  // Deprecated: use display_name (since v1.4); scheduled for removal in v2.
  string full_name = 5 [deprecated = true];
  string display_name = 6;
}
```

## Evolve `oneof` and enums deliberately
Add enum values freely (handle unknowns downstream); add a `oneof` case only when consumers can tolerate an unrecognized active case.
- **Reason:** Open enums keep new values forward-compatible, but a new `oneof` case can read as "no known case set" on older clients — design for that default branch. See [`../style/enums.md`](../style/enums.md).

```proto
enum UserStatus {
  USER_STATUS_UNSPECIFIED = 0;
  USER_STATUS_ACTIVE = 1;
  USER_STATUS_SUSPENDED = 2;
  USER_STATUS_DELETED = 3; // added later — safe
}
```

## Any wire-breaking change ⇒ new package version
If a change cannot be made additively (renumber, type-cross-group, semantic change), create a new package version rather than mutating in place.
- **Reason:** Versioned packages let v1 and v2 run side by side while clients migrate; mutating v1 breaks every existing consumer at once. See [`../api/versioning.md`](../api/versioning.md).

```proto
// Old contract preserved:           acme/user/v1/user.proto  → package acme.user.v1;
// Breaking redesign in a new one:   acme/user/v2/user.proto  → package acme.user.v2;
```

## Checklist
- [ ] Change is additive, or justified as a new version.
- [ ] Removed fields/values are `reserved` (number + name).
- [ ] Deprecations precede deletions, with a documented replacement.
- [ ] Enum/`oneof` growth accounts for unknown-case handling.
- [ ] Breaking redesigns go to `v(N+1)`, not in-place edits.
