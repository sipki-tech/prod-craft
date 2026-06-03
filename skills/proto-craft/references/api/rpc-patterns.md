# RPC Patterns

Resource-oriented design (Google AIP-style) gives APIs a predictable shape. Use the standard methods and reach for custom verbs only when they don't fit.

## The five standard methods
Model CRUD as `Get`, `List`, `Create`, `Update`, `Delete` over a resource.
- **Reason:** A consistent method set is learnable, maps to REST verbs automatically (see [`../integration/grpc-gateway.md`](../integration/grpc-gateway.md)), and lets tooling/clients generalize across resources.

```proto
service UserService {
  rpc GetUser(GetUserRequest) returns (GetUserResponse);
  rpc ListUsers(ListUsersRequest) returns (ListUsersResponse);
  rpc CreateUser(CreateUserRequest) returns (CreateUserResponse);
  rpc UpdateUser(UpdateUserRequest) returns (UpdateUserResponse);
  rpc DeleteUser(DeleteUserRequest) returns (DeleteUserResponse);
}
```

## Partial update via `FieldMask`
`Update` carries the resource plus a `google.protobuf.FieldMask` naming the fields to write.
- **Reason:** The mask distinguishes "set to empty" from "leave unchanged" — impossible to express with zero values alone. The server writes only masked paths. See [`../schema/presence-and-defaults.md`](../schema/presence-and-defaults.md).

```proto
import "google/protobuf/field_mask.proto";

message UpdateUserRequest {
  User user = 1;
  google.protobuf.FieldMask update_mask = 2; // e.g. ["display_name","locale"]
}
message UpdateUserResponse {
  User user = 1;
}
```

## Idempotency via `request_id`
Mutating RPCs that clients may retry carry a client-generated `request_id` (UUID).
- **Reason:** Network timeouts cause retries; the server dedups on `request_id` and replays the original result instead of creating duplicates or double-charging. Document the dedup window.

```proto
message CreateUserRequest {
  User user = 1;
  // request_id deduplicates retries (UUID v4); same id replays the first result.
  string request_id = 2;
}
```

## Batch with explicit `Batch*` methods
For bulk reads/writes, add `BatchGet*` / `BatchCreate*` returning parallel result lists, rather than overloading the singular method.
- **Reason:** Batch methods bound round-trips and make partial-failure semantics explicit, while keeping the singular method simple.

```proto
message BatchGetUsersRequest {
  repeated string ids = 1; // bounded; document the max
}
message BatchGetUsersResponse {
  repeated User users = 1;
}
```

## Resource-oriented names and identifiers
Prefer stable resource identifiers (an `id` or resource name) over positional or mutable lookups.
- **Reason:** Resource-oriented identity keeps `Get`/`Update`/`Delete` symmetric and cacheable, and avoids coupling clients to mutable attributes like a display name.

```proto
message GetUserRequest {
  string id = 1; // stable server-assigned identifier
}
```

## Custom methods only when CRUD doesn't fit
When an action isn't a standard method (e.g. `ArchiveUser`, `ResetPassword`), use a custom `Verb + Noun` RPC with its own request/response — sparingly.
- **Reason:** Forcing every action into CRUD distorts the model; a small number of well-named custom verbs is clearer than abusing `Update`. See [`services.md`](./services.md).

```proto
rpc ArchiveUser(ArchiveUserRequest) returns (ArchiveUserResponse);
```

## Checklist
- [ ] CRUD modeled with the five standard methods.
- [ ] `Update` uses a `FieldMask`.
- [ ] Retryable mutations carry a `request_id`.
- [ ] Bulk operations use explicit `Batch*` methods with bounded inputs.
- [ ] Resources addressed by stable identifiers.
- [ ] Custom verbs used only where CRUD genuinely doesn't fit.
