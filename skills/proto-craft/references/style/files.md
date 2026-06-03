# File Structure

A `.proto` file is a unit of compilation and a unit of review. Keep a fixed top-to-bottom order and one logical area per file.

## Always declare `syntax` first
The first non-comment line is the syntax. Use `proto3`.
- **Reason:** Without an explicit `syntax`, the compiler assumes `proto2`, silently changing presence and default semantics (see [`../schema/presence-and-defaults.md`](../schema/presence-and-defaults.md)). Editions are the future direction, but keep examples on `proto3`.

```proto
syntax = "proto3";
```

## Package = `org.area.vN`
Declare exactly one package, reverse-DNS + version, matching the directory path.
- **Reason:** The package is the cross-language namespace and the version boundary; lint expects the path (`acme/user/v1/user.proto`) to match the package (`acme.user.v1`). See [`naming.md`](./naming.md) and [`../api/versioning.md`](../api/versioning.md).

```proto
syntax = "proto3";

package acme.user.v1;
```

## Fixed layout order
Order the file: `syntax` → `package` → `imports` → file-level `option`s → types (enums, messages, services).
- **Reason:** A predictable order makes diffs and reviews fast and lets lint enforce structure mechanically.

```proto
syntax = "proto3";

package acme.user.v1;

import "google/protobuf/timestamp.proto";
import "buf/validate/validate.proto";

option go_package = "github.com/acme/api/gen/user/v1;userv1";

enum UserStatus {
  USER_STATUS_UNSPECIFIED = 0;
}

message User {
  string id = 1;
}

service UserService {
  rpc GetUser(GetUserRequest) returns (GetUserResponse);
}
```

## Set `option go_package`
Set `go_package` to the generated import path plus an explicit short package alias after `;`.
- **Reason:** Without it, Go codegen guesses the import path from the proto path, which breaks vendored or relocated modules; the explicit alias keeps the generated Go package name stable. See [`../toolkit/codegen.md`](../toolkit/codegen.md).

```proto
option go_package = "github.com/acme/api/gen/user/v1;userv1";
```

## Import hygiene: depend only on what you use
Import every file you reference, and reference every file you import. Prefer importing a small shared type over duplicating it.
- **Reason:** Unused imports are lint failures and slow compilation; missing imports break builds. Avoid `import public` unless you are intentionally re-exporting.

```proto
// Good — used below
import "google/protobuf/field_mask.proto";

message UpdateUserRequest {
  User user = 1;
  google.protobuf.FieldMask update_mask = 2;
}
```

## One logical area per file
Keep a file focused on one resource or cohesive area. Split a service, its messages, and unrelated resources across files rather than one mega-file.
- **Reason:** Small, cohesive files reduce import fan-out and merge conflicts and make ownership clear. Related shaping guidance: [`../schema/messages.md`](../schema/messages.md).

## Checklist
- [ ] `syntax = "proto3"` is the first statement.
- [ ] Exactly one `package`, matching the directory path, ending in `.vN`.
- [ ] Layout follows syntax → package → imports → options → types.
- [ ] `option go_package` set with an explicit alias.
- [ ] No unused imports; everything referenced is imported.
- [ ] File covers a single logical area.
