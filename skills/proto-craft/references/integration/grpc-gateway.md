# gRPC-Gateway (REST Mapping)

A gRPC-Gateway generates a REST/JSON reverse proxy from `google.api.http` annotations on your RPCs, so one `.proto` serves both gRPC and REST.

## Annotate RPCs with `google.api.http`
Attach an `option (google.api.http)` to each RPC that should be reachable over REST.
- **Reason:** The mapping lives with the RPC, so REST and gRPC stay generated from the single source of truth and can never silently diverge. See [`../toolkit/codegen.md`](../toolkit/codegen.md).

```proto
import "google/api/annotations.proto";

service UserService {
  rpc GetUser(GetUserRequest) returns (GetUserResponse) {
    option (google.api.http) = { get: "/v1/users/{id}" };
  }
}
```

## Match HTTP verbs to method semantics
Use `get` for reads, `post` for create, `patch` for partial update, `delete` for delete.
- **Reason:** Verb-to-semantics alignment gives a conventional REST surface that proxies, caches, and clients treat correctly. See [`../api/rpc-patterns.md`](../api/rpc-patterns.md).

```proto
rpc CreateUser(CreateUserRequest) returns (CreateUserResponse) {
  option (google.api.http) = { post: "/v1/users" body: "user" };
}
rpc UpdateUser(UpdateUserRequest) returns (UpdateUserResponse) {
  option (google.api.http) = { patch: "/v1/users/{user.id}" body: "user" };
}
rpc DeleteUser(DeleteUserRequest) returns (DeleteUserResponse) {
  option (google.api.http) = { delete: "/v1/users/{id}" };
}
```

## Path, body, and query mapping
Bind path params to request fields with `{field}`, map a sub-message to the HTTP body with `body`, and let remaining fields fall through to query parameters.
- **Reason:** Explicit binding keeps URLs clean and predictable; fields not in the path or body automatically become query params (e.g. `?page_size=50`). See [`../api/pagination.md`](../api/pagination.md).

```proto
// GET /v1/users?page_size=50&page_token=abc  → ListUsersRequest{page_size, page_token}
rpc ListUsers(ListUsersRequest) returns (ListUsersResponse) {
  option (google.api.http) = { get: "/v1/users" };
}
```

## `body: "*"` vs a named sub-message
Use `body: "user"` to accept just the resource; use `body: "*"` only when the whole request maps to the JSON body.
- **Reason:** Binding the body to a named field keeps the wire JSON aligned with the resource and leaves room for path/query fields; `*` couples the body to the entire request shape. See [`../api/services.md`](../api/services.md).

```proto
rpc CreateUser(CreateUserRequest) returns (CreateUserResponse) {
  option (google.api.http) = { post: "/v1/users" body: "user" };
}
```

## `additional_bindings` for multiple routes
Expose a second route for the same RPC with `additional_bindings` rather than duplicating the method.
- **Reason:** One handler, multiple URLs (e.g. a legacy path plus a new one) avoids divergent implementations during a migration. See [`../api/versioning.md`](../api/versioning.md).

```proto
rpc GetUser(GetUserRequest) returns (GetUserResponse) {
  option (google.api.http) = {
    get: "/v1/users/{id}"
    additional_bindings { get: "/v1/users/by-email/{email}" }
  };
}
```

## Generate OpenAPI alongside the gateway
Emit an OpenAPI/Swagger document from the same protos so REST consumers get a spec.
- **Reason:** The OpenAPI output is generated from the annotations and field comments, giving REST clients accurate docs without a hand-maintained spec. See [`../style/comments.md`](../style/comments.md).

## Checklist
- [ ] REST-exposed RPCs carry a `google.api.http` annotation.
- [ ] HTTP verbs match method semantics (get/post/patch/delete).
- [ ] Path params bound via `{field}`; body bound to a named sub-message.
- [ ] Remaining fields intentionally fall through to query params.
- [ ] `additional_bindings` used instead of duplicate methods.
- [ ] OpenAPI generated from the same protos.
