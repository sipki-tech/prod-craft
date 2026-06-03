# protovalidate

`protovalidate` declares field constraints directly in the schema using CEL-backed `buf.validate` options, and enforces them at runtime with a single interceptor. It supersedes `protoc-gen-validate` (PGV).

## Declare constraints on fields
Annotate fields with `(buf.validate.field)` constraints instead of hand-writing checks.
- **Reason:** The constraint lives with the contract, documents the rule for every consumer, and is enforced identically across languages — no per-service validation drift. See [`../api/errors.md`](../api/errors.md).

```proto
import "buf/validate/validate.proto";

message CreateUserRequest {
  User user = 1 [(buf.validate.field).required = true];
  string request_id = 2 [(buf.validate.field).string.uuid = true];
}
```

## Use the built-in standard constraints
Prefer the library's standard rules (`string.email`, `string.min_len`, numeric `gte`/`lte`, `repeated.max_items`) before reaching for custom expressions.
- **Reason:** Standard rules are concise, well-tested, and self-documenting; they cover the vast majority of validation needs. See [`../api/pagination.md`](../api/pagination.md) for the `page_size` bound.

```proto
message User {
  string email = 2 [(buf.validate.field).string.email = true];
  string display_name = 3 [(buf.validate.field).string = { min_len: 1, max_len: 64 }];
}

message ListUsersRequest {
  int32 page_size = 1 [(buf.validate.field).int32 = { gte: 0, lte: 100 }];
  string page_token = 2;
}
```

## CEL for cross-field and custom rules
Express multi-field or domain-specific rules with a `cel` expression at the field or message level.
- **Reason:** CEL handles invariants standard rules can't (e.g. "end after start") while staying declarative and portable, avoiding bespoke validator code.

```proto
message DateRange {
  google.protobuf.Timestamp start_time = 1;
  google.protobuf.Timestamp end_time = 2;

  option (buf.validate.message).cel = {
    id: "date_range.order",
    message: "end_time must be after start_time",
    expression: "this.end_time > this.start_time"
  };
}
```

## Validate once, in one interceptor
Run validation in a single server interceptor at the transport edge; don't re-validate deeper.
- **Reason:** One enforcement point means the app layer can trust its inputs, and the failure maps consistently to `INVALID_ARGUMENT` + `BadRequest`. See [`../api/errors.md`](../api/errors.md).

```text
// Interceptor: validator.Validate(req) → on failure return
// INVALID_ARGUMENT + BadRequest{field_violations} (built from the constraint failures).
```

## Migrating from protoc-gen-validate
For new schemas use `protovalidate`; when migrating PGV's `(validate.rules)` map to `(buf.validate.field)` equivalents and run validation via the interceptor instead of generated `Validate()` calls.
- **Reason:** `protovalidate` is the maintained successor — runtime CEL means no regenerated validator code and consistent behavior across languages. See [`../toolkit/codegen.md`](../toolkit/codegen.md).

## Checklist
- [ ] Field rules declared with `(buf.validate.field)`, not hand-written.
- [ ] Standard constraints used before custom CEL.
- [ ] Cross-field invariants expressed with message-level CEL.
- [ ] A single interceptor validates at the edge → `INVALID_ARGUMENT` + `BadRequest`.
- [ ] New work uses `protovalidate`; PGV rules migrated, not mixed.
