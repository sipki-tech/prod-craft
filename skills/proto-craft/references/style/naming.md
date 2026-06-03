# Naming

Names are part of the wire contract's *ergonomics*: they shape generated code in every language. Be consistent, descriptive, and free of stutter.

## Packages: reverse-DNS + version
Name packages `org.area.vN` — a reverse-DNS-style owner, the area, and a major version. Lowercase, dot-separated, no underscores.
- **Reason:** The package becomes a namespace in every target language and guards against symbol collisions; the trailing `vN` makes versioning explicit and is required by lint (see [`files.md`](./files.md) and [`../api/versioning.md`](../api/versioning.md)).

```proto
// Good
package acme.user.v1;

// Bad
package user;          // no owner, no version
package acme.userV1;   // version is not a path segment
package acme.user.V1;  // wrong case
```

## Messages and enums: PascalCase
Type names use `PascalCase`. Enums are types too.
- **Reason:** Matches the dominant generated-code convention (Go exported types, C# classes) so codegen needs no renaming.

```proto
message UserProfile {}
enum AccountState {}
```

## Fields: lower_snake_case
Field names are `lower_snake_case`. The JSON mapping derives `lowerCamelCase` automatically (see [`../integration/json-mapping.md`](../integration/json-mapping.md)).
- **Reason:** It is the canonical proto field style; let codegen pick the per-language casing instead of pre-casing the source.

```proto
message User {
  string display_name = 1;
  string email_address = 2;
}
```

## Enum values: CONSTANT_CASE with a type prefix
Enum value names are `CONSTANT_CASE` and **prefixed with the enum name**.
- **Reason:** In C++ (and historically), enum value identifiers share the *enclosing* scope, not the enum's — so unprefixed `ACTIVE` in two enums collides. The prefix also makes the value self-documenting at use sites. See [`enums.md`](./enums.md).

```proto
// Good
enum UserStatus {
  USER_STATUS_UNSPECIFIED = 0;
  USER_STATUS_ACTIVE = 1;
}

// Bad — no prefix; collides with another enum's ACTIVE
enum UserStatus {
  UNSPECIFIED = 0;
  ACTIVE = 1;
}
```

## Services and methods: PascalCase, `Verb + Noun`
Services are `PascalCase` nouns; methods are `PascalCase` imperative `Verb + Noun`. Keep a consistent service suffix policy (e.g. `UserService` or `UserAPI`) and enforce it in lint.
- **Reason:** Predictable method names map cleanly to REST verbs and read well in clients. See [`../api/services.md`](../api/services.md).

```proto
service UserService {
  rpc GetUser(GetUserRequest) returns (GetUserResponse);
  rpc ListUsers(ListUsersRequest) returns (ListUsersResponse);
  rpc CreateUser(CreateUserRequest) returns (CreateUserResponse);
}
```

## Avoid stutter
Do not repeat the package or message name inside its own members.
- **Reason:** Generated identifiers already carry the namespace; `user.v1.User.user_id` reads as noise where `user.v1.User.id` is clear.

```proto
// Good
package acme.user.v1;
message User { string id = 1; }

// Bad — stutter
message User { string user_id = 1; }
```

## Files: lower_snake_case, named after the area
Name files `lower_snake_case.proto`, matching the primary type or area (`user.proto`, `user_service.proto`).
- **Reason:** Import paths and generated file names mirror the source; predictable names keep imports readable. See [`files.md`](./files.md).

## Checklist
- [ ] Package is `org.area.vN`, lowercase, dot-separated.
- [ ] Messages/enums `PascalCase`; fields `lower_snake_case`.
- [ ] Enum values `CONSTANT_CASE` with the enum-name prefix.
- [ ] Methods are `Verb + Noun`; service suffix policy consistent.
- [ ] No stutter between a type and its members.
- [ ] File name is `lower_snake_case.proto` matching its area.
