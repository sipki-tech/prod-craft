# Enums

Go has no native enum type. Model enums as a typed integer with `iota`, an invalid zero value, a generated `String()`, and explicit conversions.

## Typed `uint8` + `iota` with an Invalid Zero
Define the enum as a distinct integer type. Start the `const` block with a blank `_` so the zero value is invalid.
- **Reason:** A distinct type prevents mixing unrelated enums. An invalid zero catches uninitialized fields (`var s UserStatus` is not silently "the first real value").

```go
type UserStatus uint8

//go:generate stringer -output=stringer.UserStatus.go -type=UserStatus -trimprefix=UserStatus
const (
    _ UserStatus = iota
    UserStatusFreeze
    UserStatusDefault
    UserStatusPremium
    UserStatusAdmin
)
```

## Generate `String()` with `stringer`
Use `//go:generate stringer` rather than hand-writing `String()`. `-trimprefix` produces clean names.
- **Reason:** Hand-written `String()` drifts when you add a value; `stringer` stays correct and is committed alongside the type.

## Add a `Valid()` Method
Provide a `Valid()` (or validate on parse) so transport/repo layers can reject the zero value and out-of-range values.

```go
func (s UserStatus) Valid() bool {
    return s >= UserStatusFreeze && s <= UserStatusAdmin
}
```

## Business-Meaning Helper Methods
Encode domain rules as methods on the enum instead of scattering comparisons.
- **Reason:** `s.IsAdmin()` reads better than `s == UserStatusAdmin` and centralizes the rule.

```go
func (s UserStatus) IsAdmin() bool    { return s == UserStatusAdmin }
func (s UserStatus) IsVerified() bool { return s != UserStatusFreeze }
```

## Exhaustive Conversion at Boundaries (panic on unknown)
Convert to/from external representations (proto, DB) with an exhaustive `switch`. `panic` in the `default` — an unknown value here is a programmer error (a new enum value without a conversion arm).
- **Reason:** The panic surfaces the missing case immediately in tests, instead of silently mapping to a wrong value. This is one of the few acceptable panics (see `style/errors.md`).

```go
func userStatusToAPI(s dom.UserStatus) userpb.Status {
    switch s {
    case dom.UserStatusFreeze:
        return userpb.Status_STATUS_FREEZE
    case dom.UserStatusDefault:
        return userpb.Status_STATUS_DEFAULT
    case dom.UserStatusPremium:
        return userpb.Status_STATUS_PREMIUM
    case dom.UserStatusAdmin:
        return userpb.Status_STATUS_ADMIN
    default:
        panic(fmt.Sprintf("unknown user status: %d", s))
    }
}
```

## Persist the Number or a Stable Code, Not the `String()` Name
Store the integer (or an explicit stable string code), never `s.String()`.
- **Reason:** `stringer` output is for humans and may be re-trimmed/renamed; persisting it couples your database to a display string.

Enums shared across the proto boundary and the app layer live in `internal/dom` — see `architecture/domain-modeling.md`.
