# Services

A service is the API surface. Keep it cohesive, name methods predictably, and give every RPC its own request and response.

## One service per resource or cohesive area
Group RPCs that operate on the same resource into one service; split unrelated resources into separate services.
- **Reason:** A focused `UserService` is easy to authorize, version, and document; a god-service mixing users, billing, and search becomes impossible to evolve independently. See [`versioning.md`](./versioning.md).

```proto
service UserService {
  rpc GetUser(GetUserRequest) returns (GetUserResponse);
  rpc ListUsers(ListUsersRequest) returns (ListUsersResponse);
  rpc CreateUser(CreateUserRequest) returns (CreateUserResponse);
}
```

## Method names are `Verb + Noun`
Name methods imperatively: `GetUser`, `ListUsers`, `CreateUser`, `UpdateUser`, `DeleteUser`. Plural noun for `List*`, singular elsewhere.
- **Reason:** Predictable verbs map cleanly to REST methods via the gateway and read well in generated clients. See [`rpc-patterns.md`](./rpc-patterns.md) and [`../integration/grpc-gateway.md`](../integration/grpc-gateway.md).

```proto
rpc GetUser(GetUserRequest) returns (GetUserResponse);
rpc ListUsers(ListUsersRequest) returns (ListUsersResponse);
rpc CreateUser(CreateUserRequest) returns (CreateUserResponse);
```

## Every RPC owns a named `XRequest` and `XResponse`
Define a dedicated `MethodNameRequest` and `MethodNameResponse` for each RPC.
- **Reason:** These wrappers can gain fields (pagination, `FieldMask`, `request_id`, future filters) additively without changing the RPC signature — the single most important evolvability lever in a gRPC API. See [`../schema/messages.md`](../schema/messages.md).

```proto
message GetUserRequest {
  string id = 1;
}
message GetUserResponse {
  User user = 1;
}
```

## Never take or return bare scalars
Do not declare RPCs over scalar types, `Empty`, or a shared domain entity.
- **Reason:** A bare scalar (`returns (string)`) or `Empty` cannot grow a field without breaking the contract; a shared request entangles unrelated methods. The named wrapper is the escape hatch. See [`../style/well-known-types.md`](../style/well-known-types.md).

```proto
// Bad
rpc GetUserName(GetUserRequest) returns (StringValue); // can't add fields
rpc DeleteUser(DeleteUserRequest) returns (google.protobuf.Empty);

// Good
rpc DeleteUser(DeleteUserRequest) returns (DeleteUserResponse); // {} today, growable
```

## No shared request messages across RPCs
Each method gets its own request type, even if two look identical today.
- **Reason:** Sharing couples the methods: the day one needs a new field, you either break the other or fork anyway. Separate types keep methods independently evolvable. See [`../schema/evolution.md`](../schema/evolution.md).

```proto
// Bad — both reuse one request; they will diverge
rpc GetUser(UserRequest) returns (GetUserResponse);
rpc DeleteUser(UserRequest) returns (DeleteUserResponse);

// Good — independent requests
rpc GetUser(GetUserRequest) returns (GetUserResponse);
rpc DeleteUser(DeleteUserRequest) returns (DeleteUserResponse);
```

## Checklist
- [ ] Service scoped to one resource/area.
- [ ] Methods are `Verb + Noun`; `List*` is plural.
- [ ] Every RPC has its own `XRequest` and `XResponse`.
- [ ] No bare scalars or `Empty` in signatures.
- [ ] No request message shared between RPCs.
