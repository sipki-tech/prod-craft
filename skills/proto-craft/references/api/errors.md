# Error Model

gRPC errors are structured values, not strings. Use canonical status codes plus typed `errdetails`, and never leak internals.

## Use `google.rpc.Status` + canonical codes
Return failures as a status `code` (from the canonical set) with a short, human-readable `message`. Don't invent your own error envelope inside the response message.
- **Reason:** Every gRPC client understands the canonical codes and the `Status` shape; a bespoke `error` field in your response forces custom handling and breaks streaming/interceptor tooling.

```proto
import "google/rpc/status.proto";
import "google/rpc/error_details.proto";

// Conceptual: servers return a Status; clients read code + details.
// message Status { int32 code = 1; string message = 2; repeated google.protobuf.Any details = 3; }
```

## Map domain situations to canonical codes
Translate each domain error to the closest canonical code in one place (an interceptor), not ad hoc per handler.
- **Reason:** Clients branch on `code`, so the mapping must be consistent and centralized. See [`../integration/protovalidate.md`](../integration/protovalidate.md) for validation→`INVALID_ARGUMENT`.

```text
validation failure   → INVALID_ARGUMENT      (+ BadRequest)
not found            → NOT_FOUND             (+ ResourceInfo)
duplicate / conflict → ALREADY_EXISTS / ABORTED (+ ErrorInfo)
missing/invalid auth → UNAUTHENTICATED
forbidden            → PERMISSION_DENIED     (+ ErrorInfo)
rate limited         → RESOURCE_EXHAUSTED    (+ QuotaFailure, RetryInfo)
transient/backoff    → UNAVAILABLE           (+ RetryInfo)
bug / unexpected     → INTERNAL              (no internal detail)
```

## Carry machine-readable detail in `errdetails`
Put structured, client-actionable detail in standard `errdetails` messages, not in the free-text `message`.
- **Reason:** Clients can parse `BadRequest.field_violations` or `RetryInfo.retry_delay`; they cannot reliably parse English prose. Use `ErrorInfo` for a stable `reason` + `domain`.

```proto
// Conceptual payloads attached to Status.details:
// BadRequest { repeated FieldViolation field_violations = 1; }  // field + description
// ErrorInfo  { string reason = 1; string domain = 2; map<string,string> metadata = 3; }
// QuotaFailure, RetryInfo, ResourceInfo, PreconditionFailure ...
```

## `BadRequest` for field-level validation errors
Return `INVALID_ARGUMENT` with a `BadRequest` listing each offending field and why.
- **Reason:** Field-scoped violations let clients highlight the exact input that failed; a single opaque message cannot. This pairs with declarative validation (see [`../integration/protovalidate.md`](../integration/protovalidate.md)).

```text
code = INVALID_ARGUMENT
details = BadRequest {
  field_violations = [
    { field: "email", description: "must be a valid email address" },
    { field: "page_size", description: "must be between 1 and 100" },
  ]
}
```

## `ErrorInfo` for stable, programmatic reasons
Attach an `ErrorInfo` with a stable `reason` (e.g. `EMAIL_ALREADY_EXISTS`) and a `domain` for conditions clients must branch on.
- **Reason:** The `reason` is a stable enum-like string clients can switch on across versions, decoupling them from message wording and even from the exact code. See [`versioning.md`](./versioning.md).

## Never leak internals
Map unexpected failures to `INTERNAL` with a generic message; never surface stack traces, SQL, driver errors, or PII.
- **Reason:** Leaked internals are an information-disclosure risk and couple clients to implementation details. Log the real cause server-side; return an opaque error id if correlation is needed.

```text
// Good:  INTERNAL "internal error" (+ correlation id)
// Bad:   INTERNAL "pq: duplicate key value violates unique constraint \"users_email_key\""
```

## Checklist
- [ ] Failures use `google.rpc.Status` + canonical codes, not a custom envelope.
- [ ] Domain→code mapping centralized in one interceptor.
- [ ] Machine-readable detail in `errdetails`, not the message string.
- [ ] Validation errors return `INVALID_ARGUMENT` + `BadRequest`.
- [ ] Stable `ErrorInfo.reason` provided for branchable conditions.
- [ ] No stack traces, SQL, driver errors, or PII in responses.
