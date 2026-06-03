# Input Validation

Reject malformed input at the edge, then trust your types inward. The goal is "parse, don't validate": convert untrusted input into a domain type that *cannot* be invalid, once, at the boundary.

## Validate at the Transport Edge
The transport layer owns **syntactic** validation of the request DTO: required fields present, lengths/ranges, formats, enum membership. Reject before the request reaches the app layer.
- **Reason:** the app layer should operate on already-well-formed input and focus on *business* rules, not field shape.

## Parse, Don't Validate
Don't pass primitive strings around and re-check them everywhere. Construct a domain value object once; if it exists, it is valid.
```go
// dom/email.go — see architecture/domain-modeling.md and style/enums.md
func NewEmail(s string) (Email, error) {
    s = strings.TrimSpace(strings.ToLower(s))
    if !emailRe.MatchString(s) {
        return "", fmt.Errorf("%w: email", ErrInvalidInput)
    }
    return Email(s), nil
}
```
After this, every function taking an `Email` is spared a re-check — compare with the anti-pattern of `func send(to string)` that re-validates `to` in five places.

## Generated/Declarative Validation for Wire DTOs
For proto-defined APIs, declare constraints in the schema and generate validators (e.g. `buf validate` / protoc-gen-validate), then run **one** interceptor that calls `Validate()` and maps failures to `InvalidArgument`. See [`../toolkit/protobuf.md`](../toolkit/protobuf.md) and [`grpc-api.md`](./grpc-api.md).
```proto
string email = 1 [(buf.validate.field).string.email = true];
int32  age    = 2 [(buf.validate.field).int32 = {gte: 0, lte: 130}];
```
- **Reason:** the contract documents and enforces the same rules; no hand-written boilerplate to drift.

## Map Failures to the Right Error
- **Transport/syntactic** failure → `400 Bad Request` / gRPC `InvalidArgument`, with a field-level message (use `errdetails.BadRequest`; see [`grpc-api.md`](./grpc-api.md)).
- **Business-rule** failure (e.g. "email already taken") → a domain sentinel (`ErrEmailExist`) surfaced as the appropriate code (`AlreadyExists`), **not** `InvalidArgument`.
- Keep messages **actionable but not leaky**: say which field is wrong, never echo secrets or internal state ([`../security/security.md`](../security/security.md)).

## Normalize Before Validating
Trim whitespace, lowercase emails, canonicalize unicode, and strip or reject control characters — *then* validate, so equivalent inputs are treated equally and stored consistently.

## Don't Trust Client-Supplied Invariants
Server-authoritative fields (the acting user's id, prices, roles, timestamps) come from the **session/context or the DB**, never from the request body. Validate that referenced ids belong to the caller (authorization, [`../security/auth.md`](../security/auth.md)), not merely that they are well-formed.

## Boundaries, Not Everywhere
Validate once at the edge and at value-object construction. Re-validating the same value deep in the call stack is noise — if you feel the urge, your types are too primitive: push the check into a constructor instead.

## Checklist
- [ ] Request DTOs validated at the transport edge before the app layer.
- [ ] Domain value objects built through validating constructors (parse-don't-validate).
- [ ] Wire constraints declared in the schema + generated validator + one interceptor.
- [ ] Syntactic errors → `InvalidArgument`/`400`; business errors → domain sentinels.
- [ ] Inputs normalized before validation.
- [ ] Server-authoritative fields taken from context/DB, never the client.
