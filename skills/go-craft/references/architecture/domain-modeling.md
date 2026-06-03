# Domain Modeling

Model the domain in pure Go types, free of transport and storage concerns. Each layer owns its own representation and converts at the boundary.

## Entities vs Value Objects
- **Entity** — has identity that persists across changes (`User` with an `ID`).
- **Value object** — defined entirely by its fields, immutable, no identity (`Money`, `Email`, `Origin`).
- **Reason:** Treating a value object as an entity (or vice versa) leads to wrong equality and accidental mutation.

```go
// Value object: compared by value, never mutated
type Origin struct {
    IP        net.IP
    UserAgent string
}

// Entity: identified by ID
type User struct {
    ID     uuid.UUID
    Email  string
    Status dom.UserStatus
}
```

## Keep Domain Types Free of Tags
Domain entities have **no** `json:`/`db:`/`protobuf:` tags. Those belong on per-layer models.
- **Reason:** Tagging the domain couples the core to wire and storage formats and leaks internal fields onto the API.

## A Model per Layer + Explicit Converters
Each boundary has its own struct and a conversion function. Conversions are small, total, and tested.
- **Reason:** The DB column set, the wire shape, and the domain invariant evolve independently. Explicit `toX` functions make the mapping reviewable.

```text
userpb.User   <-- (transport) toAPI / fromAPI -->   app.User   <-- (repo) toDomain / toRow -->   userRow
```

```go
// adapters/repo/user_model.go
type userRow struct {
    ID     uuid.UUID `db:"id"`
    Email  string    `db:"email"`
    Status uint8     `db:"status"`
}

func (r userRow) toDomain() *app.User {
    return &app.User{ID: r.ID, Email: r.Email, Status: dom.UserStatus(r.Status)}
}

func rowFromDomain(u app.User) userRow {
    return userRow{ID: u.ID, Email: u.Email, Status: uint8(u.Status)}
}
```

```go
// api/grpc/convert.go
func userToAPI(u app.User) *userpb.User {
    return &userpb.User{Id: u.ID.String(), Email: u.Email, Status: userStatusToAPI(u.Status)}
}
```

## Anti-Corruption Layer (ACL)
When the other side of a boundary is an **external** system (a third-party API, a legacy service, an OAuth provider), the same per-layer-model + converter discipline becomes an *anti-corruption layer*: translate the foreign model into your domain inside the adapter, and never let its vocabulary leak inward.
- **Reason:** External schemas are unstable and shaped by someone else's concerns. Converting at the edge absorbs an upstream breaking change in one converter instead of spreading it through your core. See [`../recipes/outbound-http.md`](../recipes/outbound-http.md) and [`../security/oauth.md`](../security/oauth.md).

```go
// adapters/oauth/google.go — foreign claims become a domain type at the edge.
func (p *GoogleProvider) Validate(ctx context.Context, token string) (*app.OAuthUserInfo, error) {
    payload, err := idtoken.Validate(ctx, token, p.clientID)
    if err != nil {
        return nil, fmt.Errorf("%w: %w", ErrInvalidToken, err)
    }
    sub, _ := payload.Claims["sub"].(string)
    email, _ := payload.Claims["email"].(string)
    return &app.OAuthUserInfo{ID: sub, Email: email}, nil // your type, not the provider's
}
```

## The Shared Kernel: `internal/dom`
Cross-cutting domain types used by **both** the app layer and the proto/transport boundary live in a dependency-free `internal/dom` package: enums, shared value objects, and cross-adapter sentinel errors.
- **Reason:** If `app` imported the proto package (or vice versa) for a shared enum, you'd get an import cycle. `dom` is imported by everyone and imports nothing internal.

```go
// internal/dom/user_status.go
package dom

type UserStatus uint8 // enum with stringer + helpers; see style/enums.md
```

## Where Sentinel Errors Live
- Shared across multiple adapters/layers → `internal/dom`.
- App-only → `app/error.go`.
- **Reason:** Mirrors the import graph: shared errors must sit where everyone can import them. See `style/errors.md` and `architecture/clean.md`.

## Validate Invariants at Construction
Build value objects through constructors that enforce invariants (`NewEmail` rejects malformed input), so the rest of the code can trust the type.
- **Reason:** "Parse, don't validate" — once you hold a `Email`, it's valid everywhere; you don't re-check.
