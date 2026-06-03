# Code Generation

Generate all language artifacts from the `.proto` in one deterministic pass, and commit the output so consumers build without the proto toolchain.

## Generate messages, gRPC, gateway, and OpenAPI together
Declare every plugin in one generation config so a single command produces the full set.
- **Reason:** One pass keeps the artifacts mutually consistent (the gateway matches the messages) and removes per-plugin drift. See [`easyp.md`](./easyp.md) and the starter [`../../assets/buf.gen.yaml`](../../assets/buf.gen.yaml).

```yaml
# easyp.yaml — generate block
generate:
  inputs:
    - directory: api
  plugins:
    - remote: api.beta.easyp.tech/protocolbuffers/go
      out: .
      opts: { paths: source_relative }
    - remote: api.beta.easyp.tech/grpc/go
      out: .
      opts: { paths: source_relative, require_unimplemented_servers: false }
    - remote: api.beta.easyp.tech/grpc-ecosystem/gateway
      out: .
      opts: { paths: source_relative }
    - remote: api.beta.easyp.tech/grpc-ecosystem/openapiv2
      out: .
    # protovalidate validates at runtime (CEL) — no codegen plugin (see ../integration/protovalidate.md).
```

## buf fallback: `buf.gen.yaml`
The buf equivalent lists the same plugins in `buf.gen.yaml`.
- **Reason:** The mapping is provided for teams migrating from buf. Generated code is the same regardless of toolchain. See the starter [`../../assets/buf.gen.yaml`](../../assets/buf.gen.yaml).

```yaml
# buf.gen.yaml — parity
version: v2
plugins:
  - remote: buf.build/protocolbuffers/go
    out: gen
    opt: paths=source_relative
  - remote: buf.build/grpc/go
    out: gen
    opt: paths=source_relative
```

## `go_package` controls Go output location
Set `option go_package` in every file so Go output lands at a stable import path with a stable package alias.
- **Reason:** Without it codegen guesses from the proto path and breaks on relocation; the explicit `;alias` fixes the generated package name. See [`../style/files.md`](../style/files.md).

```proto
option go_package = "github.com/acme/api/gen/user/v1;userv1";
```

## Commit the generated artifacts
Check in `*.pb.go`, `*_grpc.pb.go`, `*.pb.gw.go`, and `*.swagger.json`.
- **Reason:** Consumers and the backend build from the same committed contract without installing the proto toolchain, and reviewers see the contract diff. Exclude generated files from Go lint/format.

```text
# Generated, committed, excluded from linters:
api/acme/user/v1/user.pb.go
api/acme/user/v1/user_grpc.pb.go
api/acme/user/v1/user.pb.gw.go
api/acme/user/v1/user.swagger.json
# user.pb.validate.go only with legacy protoc-gen-validate; protovalidate is runtime.
```

## Pin plugin versions for deterministic output
Pin each plugin to a specific version so regeneration is reproducible.
- **Reason:** Unpinned plugins produce diff noise (or break) when a new version ships; pinning makes "regenerate" idempotent and CI's freshness check meaningful. See [`ci.md`](./ci.md).

```yaml
plugins:
  - remote: api.beta.easyp.tech/protocolbuffers/go:v1.36.10  # pinned
    out: .
    opts: { paths: source_relative }
```

## Checklist
- [ ] One generation config produces messages, gRPC, gateway, validation, and OpenAPI.
- [ ] `option go_package` set in every file.
- [ ] Generated artifacts committed and excluded from Go linters.
- [ ] Plugin versions pinned for reproducible output.
