# Protobuf & gRPC Codegen

Treat `.proto` files as the **single source of truth** for your API. Generate Go (messages, gRPC, gateway, validation, OpenAPI) from them, lint them, and check for breaking changes in CI. Use `buf` as the default tool; `EasyP` is a drop-in alternative with the same config shape if you need its extra rules or a single static binary.

## Tool Choice

| Tool | Use when |
|---|---|
| `buf` | Default. Mature, fast, BSR remote plugins, broad ecosystem. |
| `EasyP` | Drop-in `buf` replacement (`easyp lint`, `easyp generate`, `easyp mod`). Same `easyp.yaml` shape; extra opinionated lint rules. Pick one and stay consistent. |

Both are far better than hand-rolled `protoc` bash scripts: deterministic builds, dependency management, built-in lint + breaking-change detection.

## Installation
```bash
brew install bufbuild/buf/buf   # or: go install github.com/bufbuild/buf/cmd/buf@latest
```

## Configuration (buf v2)
`buf.yaml` declares modules, lint, and breaking rules. Keep it at the repo root with `api/` as the module path.

```yaml
# buf.yaml
version: v2
modules:
  - path: api
lint:
  use:
    - STANDARD
  except:
    - PACKAGE_VERSION_SUFFIX   # opt out per-rule, with intent
breaking:
  use:
    - FILE
```

`buf.gen.yaml` declares generation targets. Generate messages, gRPC, the REST gateway, validation, and OpenAPI in one pass.

```yaml
# buf.gen.yaml
version: v2
plugins:
  - local: protoc-gen-go
    out: api
    opt: paths=source_relative
  - local: protoc-gen-go-grpc
    out: api
    opt: paths=source_relative
  - local: protoc-gen-grpc-gateway
    out: api
    opt: paths=source_relative
  - local: protoc-gen-validate-go    # or protovalidate
    out: api
    opt: paths=source_relative
  - local: protoc-gen-openapiv2
    out: api
```

## Lint, Format, Breaking
```bash
buf format -w                          # format in place
buf lint                               # style violations
buf breaking --against '.git#branch=main'   # block breaking changes vs main
buf generate                           # codegen
```

Wire these into your task runner (`task lint` runs `buf lint`; CI also runs `buf breaking`).

## Commit Generated Code
**Commit the generated artifacts** (`*.pb.go`, `*.pb.gw.go`, `*.pb.validate.go`, `*.swagger.json`).
- **Reason:** Consumers and the backend build from the same committed contract without needing the proto toolchain installed, and code review can see contract diffs.

Exclude generated files from linting and formatting (see `toolkit/linting.md` — `issues.exclude-files` / `paths`).

## Validation at the Boundary
Declare field constraints in the proto and validate once, at the transport edge — never re-validate ad hoc deeper in the stack.

```proto
message CreateUserRequest {
  string email = 1 [(buf.validate.field).string.email = true];
  string name  = 2 [(buf.validate.field).string = {min_len: 1, max_len: 64}];
}
```

## Working with Generated Code in Go
Use the modern `google.golang.org/protobuf/proto` API, not the deprecated `github.com/golang/protobuf/proto`.

```go
// Good
import "google.golang.org/protobuf/proto"

b, err := proto.Marshal(msg)
```

See `recipes/grpc-api.md` for method/error/pagination design and `architecture/domain-modeling.md` for converting generated types to domain types at the transport boundary.
