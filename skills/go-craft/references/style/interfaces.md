# Interfaces

Interfaces define behavior contracts. Keep them small, define them where they are consumed, and document their error contract.

## Accept Interfaces, Return Structs
Functions accept interface parameters (so callers can substitute implementations) and return concrete structs (so callers get the full type).
- **Reason:** This minimizes coupling on input and maximizes usability on output.

```go
// Good
func New(r Repo, c Cache) *Service { ... } // accepts interfaces
func (s *Service) User(...) (*User, error)  // returns concrete *User
```

## Define Interfaces in the Consumer
The package that *uses* a dependency declares the interface it needs; the implementing package does not export one.
- **Reason:** The consumer dictates the minimal method set. This avoids fat, implementation-driven interfaces and breaks import cycles. See `architecture/clean.md`.

```go
// app/contracts.go — the app declares what it needs
package app

type Repo interface {
    // UserByID returns user info by id.
    // Errors: ErrNotFound, unknown.
    UserByID(ctx context.Context, id uuid.UUID) (*User, error)
}
```

## Don't Create an Interface Until You Need One
A single implementation with no test-doubling need does not require an interface. Introduce one when you (a) mock it in tests at a boundary, or (b) genuinely have multiple implementations.
- **Reason:** Premature interfaces add indirection without value and obscure the call graph.

## Keep Interfaces Small
Prefer one-to-three method interfaces. Large boundary contracts (a `Repo` with many methods) are acceptable but mark them deliberately.
- **Reason:** Small interfaces compose and are trivial to fake. The standard library's power comes from `io.Reader`/`io.Writer`.

```go
//nolint:interfacebloat // boundary contract intentionally lists every repo method
type Repo interface { /* many methods */ }
```

## Document the Error Contract
Every interface method's godoc lists the sentinel errors it may return, ending with `unknown` for wrapped infrastructure errors.
- **Reason:** Callers build `switch errors.Is(...)` logic from this contract. See `style/errors.md`.

```go
// UserSave adds the new user to the repository.
// Errors: ErrEmailExist, ErrUsernameExist, unknown.
UserSave(ctx context.Context, user User) (uuid.UUID, error)
```

## Compile-Time Implementation Assertions
Assert that a type satisfies an interface with a blank `var`. Place it near the implementation.
- **Reason:** You get a clear compile error at the definition, not a confusing one at a distant call site.

```go
var _ app.Repo = (*Repo)(nil)
```

## Beware the Typed-Nil Interface
A non-nil interface can hold a nil concrete pointer. Returning a typed nil and comparing the interface to `nil` is a classic bug.
- **Reason:** The interface stores `(type, value)`; a nil `*T` makes the value nil but the type non-nil, so `iface != nil`.

```go
// Bad
func get() error {
    var e *MyError // nil
    return e       // returned interface is NON-nil!
}

// Good — return nil explicitly
func get() error {
    if !failed {
        return nil
    }
    return &MyError{}
}
```
