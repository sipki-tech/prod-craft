# Enums

An enum is a closed set of named integers on the wire. Make the zero value mean "unset" and keep the names collision-safe.

## First value is `*_UNSPECIFIED = 0`
Every enum's first value is `<ENUM_NAME>_UNSPECIFIED = 0`.
- **Reason:** proto3 has no field presence for bare enums, so an unset enum reads back as `0`. A zero `*_UNSPECIFIED` makes "the sender didn't set this" distinguishable from a real choice, and lint enforces it.

```proto
enum UserStatus {
  USER_STATUS_UNSPECIFIED = 0;
  USER_STATUS_ACTIVE = 1;
  USER_STATUS_SUSPENDED = 2;
}
```

## `CONSTANT_CASE` with a type-name prefix
Prefix every value with the enum name in `CONSTANT_CASE`.
- **Reason:** Enum value identifiers live in the *enclosing* scope (C++ scoping rules), so two enums with an unprefixed `ACTIVE` collide. The prefix prevents that and is self-documenting at call sites. See [`naming.md`](./naming.md).

```proto
// Good
enum OrderState {
  ORDER_STATE_UNSPECIFIED = 0;
  ORDER_STATE_PENDING = 1;
}

// Bad — unprefixed; collides with another enum's PENDING
enum OrderState {
  UNSPECIFIED = 0;
  PENDING = 1;
}
```

## `reserved` removed values
When you remove an enum value, reserve its number and name.
- **Reason:** Like fields, enum numbers carry meaning on the wire; reserving both prevents a future value silently reusing a retired number or name. See [`../schema/evolution.md`](../schema/evolution.md).

```proto
enum PaymentMethod {
  reserved 3, 4;
  reserved "PAYMENT_METHOD_BITCOIN";

  PAYMENT_METHOD_UNSPECIFIED = 0;
  PAYMENT_METHOD_CARD = 1;
  PAYMENT_METHOD_BANK_TRANSFER = 2;
}
```

## `allow_alias` only with intent
Two value names may share a number only if you set `option allow_alias = true;`. Use it sparingly, e.g. when renaming a value while keeping the old name temporarily.
- **Reason:** Aliasing is normally a bug (a typo'd duplicate); requiring the explicit option turns an accidental duplicate into a compile error and documents deliberate aliases.

```proto
enum Color {
  option allow_alias = true;
  COLOR_UNSPECIFIED = 0;
  COLOR_RED = 1;
  COLOR_CRIMSON = 1; // intentional alias of RED
}
```

## Open vs closed semantics
proto3 enums are **open**: an unknown number deserializes and is preserved as-is rather than rejected. Treat any unrecognized value as `*_UNSPECIFIED` in business logic, and never assume the set is exhaustive on the wire.
- **Reason:** A newer client may send a value an older server has never heard of; open enums keep that forward-compatible, but your code must handle the unknown branch explicitly. See [`../schema/compatibility.md`](../schema/compatibility.md).

```proto
// Consumers must handle an unknown value defensively, e.g.:
// switch s { case ACTIVE: ...; case SUSPENDED: ...; default: treatAsUnspecified() }
```

## Prefer an enum over a boolean for states
Model a state or mode as an enum, not a `bool`, when there may ever be a third option.
- **Reason:** A `bool` cannot grow; a state that becomes tri-state forces a breaking redesign. An enum starts with two values and adds a third additively. See [`../schema/messages.md`](../schema/messages.md).

## Checklist
- [ ] First value is `*_UNSPECIFIED = 0`.
- [ ] Values are `CONSTANT_CASE` with the enum-name prefix.
- [ ] Removed values are `reserved` (number and name).
- [ ] `allow_alias` set only for intentional aliases.
- [ ] Business logic treats unknown numbers as unspecified.
- [ ] Multi-state concepts modeled as enums, not booleans.
