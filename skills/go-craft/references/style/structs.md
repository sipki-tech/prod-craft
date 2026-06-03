# Struct Design

Structs are Go's primary aggregate. Design them so the zero value is useful, fields are ordered intentionally, and tags are consistent.

## Make the Zero Value Useful
Where possible, a freshly declared struct should be usable without a constructor.
- **Reason:** `sync.Mutex`, `bytes.Buffer`, and `strings.Builder` all work at their zero value. It removes a class of "forgot to call New" bugs.

```go
// Good — zero value is a ready-to-use, unlocked mutex
var mu sync.Mutex
mu.Lock()

// When invariants are required, force construction:
type Service struct{ repo Repo }
func New(r Repo) *Service { return &Service{repo: r} } // repo must be set
```

## Constructors for Required Invariants
When a struct needs non-zero dependencies or validation, provide `New...` returning `*T` (or `(*T, error)`), and keep dependency fields unexported.
- **Reason:** Unexported fields force callers through the constructor, guaranteeing invariants.

## Group Related Declarations in `type ()` Blocks
Group conceptually related types in one `type (...)` block with a doc comment per type.
- **Reason:** A visual signal that the types belong to the same domain.

```go
type (
    // User contains user information.
    User struct {
        ID       uuid.UUID
        Email    string
        Name     string
        Status   dom.UserStatus
    }

    // Session identifies an authenticated user.
    Session struct {
        ID     uuid.UUID
        UserID uuid.UUID
        Token  Token
    }
)
```

## Field Ordering
Order fields for readability first; if a struct is allocated in huge volumes, consider alignment (largest to smallest) to reduce padding.
- **Reason:** Readability matters far more than padding for 99% of structs. Reach for `fieldalignment` only on hot, high-cardinality types.

## Struct Tags Are `snake_case`, Enforced
JSON, YAML, DB, etc. tags use `snake_case`, enforced by `tagliatelle` (see `toolkit/linting.md`).
- **Reason:** Consistent wire/DB naming prevents contract mismatches.

```go
type userRow struct {
    ID        uuid.UUID `db:"id"`
    Email     string    `db:"email"`
    CreatedAt time.Time `db:"created_at"`
}
```

## Separate Wire/DB Models from Domain Types
Don't put `json:`/`db:` tags on your domain entities. Keep a `userRow` (DB) / `userDTO` (wire) next to the boundary and convert. See `architecture/domain-modeling.md`.
- **Reason:** Tagging domain types couples the core to transport and storage representations and leaks fields.

## Avoid Embedding for Code Reuse
Embed to satisfy an interface or extend behavior deliberately — not merely to "inherit" fields. Never embed a `sync.Mutex` in an exported struct (it leaks `Lock`/`Unlock`).
- **Reason:** Embedding promotes the inner type's methods to the outer's public API, often unintentionally.

## Prefer `*T` for Optional/Mutable, `T` for Small Values
Return `*User` when nil means "absent" or the struct is large/mutated; return `User`/value for small immutable values.
- **Reason:** Pointers communicate optionality and avoid copies, but add nil-checks and escape to the heap.
