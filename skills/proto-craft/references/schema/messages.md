# Message Design

A message is a contract for a chunk of data. Shape it for clarity and additive evolution, not for what is convenient today.

## Compose with references, nest only for ownership
Reference shared types by name; nest a message only when it is owned by and meaningless outside its parent.
- **Reason:** A top-level `Address` can be reused and evolved independently; a nested `User.Preferences` signals it belongs solely to `User`. Over-nesting buries types and bloats generated names.

```proto
// Good — reusable top-level type
message Address {
  string line1 = 1;
  string city = 2;
}

message User {
  Address billing_address = 1;

  // Nested: only meaningful inside User.
  message Preferences {
    string locale = 1;
  }
  Preferences preferences = 2;
}
```

## `oneof` for mutually exclusive fields
When at most one of several fields may be set, model them as a `oneof`.
- **Reason:** A `oneof` enforces exclusivity on the wire and generates a tagged union, replacing a cluster of `optional` fields plus a hand-checked "exactly one" invariant. Note: `oneof` members cannot be `repeated`.

```proto
message Notification {
  string id = 1;
  oneof channel {
    EmailChannel email = 2;
    SmsChannel sms = 3;
    PushChannel push = 4;
  }
}
```

## Group related fields into sub-messages
When several fields always travel together, extract them into a sub-message.
- **Reason:** Grouping documents cohesion, lets the group be reused or made `optional`/`repeated` as a unit, and shrinks the parent's field-number surface.

```proto
// Good
message Order {
  Money subtotal = 1;
  Money tax = 2;
}
message Money {
  string currency_code = 1; // ISO 4217
  int64 amount_minor = 2;   // smallest unit, e.g. cents
}
```

## Prefer enums over booleans for states
Use an enum where a `bool` would represent a state that might gain a third value.
- **Reason:** Booleans cannot evolve; a tri-state need forces a breaking change, while an enum grows additively. See [`../style/enums.md`](../style/enums.md).

```proto
// Good — can add HOLD, CLOSED later
enum AccountState {
  ACCOUNT_STATE_UNSPECIFIED = 0;
  ACCOUNT_STATE_ACTIVE = 1;
  ACCOUNT_STATE_SUSPENDED = 2;
}

// Risky — is_active cannot express "suspended"
// bool is_active = 1;
```

## Shape requests and responses as dedicated messages
Each RPC's input and output is its own named message, even for one field. Do not reuse a domain entity (`User`) directly as a request.
- **Reason:** A wrapper request can gain fields (pagination, masks, request_id) without breaking the RPC signature; passing `User` directly cannot. See [`../api/services.md`](../api/services.md).

```proto
message GetUserRequest {
  string id = 1;
}
message GetUserResponse {
  User user = 1;
}
```

## Checklist
- [ ] Shared types are top-level; nesting reserved for true ownership.
- [ ] Mutually exclusive fields use `oneof`.
- [ ] Cohesive field clusters extracted into sub-messages.
- [ ] States modeled as enums, not booleans.
- [ ] Every RPC has dedicated request/response messages, not bare entities.
