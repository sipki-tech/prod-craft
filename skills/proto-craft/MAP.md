# `proto-craft` Navigation Map

Load only the files relevant to your current task. Each row says when to read it. Three cross-cutting rules underpin everything: **field numbers are permanent** (`schema/compatibility.md`), **every enum has `*_UNSPECIFIED = 0`** (`style/enums.md`), and **every RPC owns its named request/response** (`api/services.md`).

## 🎨 Style

| File | When to Read |
|---|---|
| [`style/naming.md`](./references/style/naming.md) | Naming packages (reverse-DNS + version), messages, fields, enums, services, methods, files; case rules; avoiding stutter. |
| [`style/files.md`](./references/style/files.md) | `syntax`, `package`, file layout order, `option go_package`, import hygiene, one logical area per file. |
| [`style/fields.md`](./references/style/fields.md) | Field numbers (1–15 cost, reserve ranges), never renumber/reuse, `reserved`, scalar choice, repeated/map, explicit `optional`. |
| [`style/enums.md`](./references/style/enums.md) | First value `*_UNSPECIFIED = 0`, `CONSTANT_CASE` + type prefix, `reserved`, `allow_alias`, open vs closed. |
| [`style/well-known-types.md`](./references/style/well-known-types.md) | `Timestamp`/`Duration`, `FieldMask`, `Struct`/`Value`, `Any`, wrappers, `Empty` — when to use each. |
| [`style/comments.md`](./references/style/comments.md) | Doc comments on every symbol; units/invariants; `[deprecated = true]`; explaining the "why". |

## 🧱 Schema

| File | When to Read |
|---|---|
| [`schema/messages.md`](./references/schema/messages.md) | Composition vs nesting, `oneof` for mutual exclusivity, grouping, enum-not-bool, request/response shaping. |
| [`schema/compatibility.md`](./references/schema/compatibility.md) | Wire-compat table (safe vs breaking), type-compat groups, number stability, rename caveats. |
| [`schema/evolution.md`](./references/schema/evolution.md) | Additive-only changes, reserve on removal, `oneof`/enum evolution, deprecation flow, when to bump versions. |
| [`schema/presence-and-defaults.md`](./references/schema/presence-and-defaults.md) | Implicit vs explicit presence, no custom defaults, absence on the wire and in codegen, `FieldMask` for unset-vs-zero. |

## 🌐 API

| File | When to Read |
|---|---|
| [`api/services.md`](./references/api/services.md) | Service granularity, `Verb+Noun` method naming, one named `XRequest`/`XResponse` per RPC, no bare scalars. |
| [`api/rpc-patterns.md`](./references/api/rpc-patterns.md) | Standard methods (Get/List/Create/Update/Delete/Batch), `FieldMask` updates, resource orientation, idempotency. |
| [`api/errors.md`](./references/api/errors.md) | `google.rpc.Status` + canonical codes, `errdetails` (BadRequest/ErrorInfo/QuotaFailure/RetryInfo), no leaks. |
| [`api/pagination.md`](./references/api/pagination.md) | Cursor pagination (`page_size` + opaque `page_token` → `next_page_token`), stable ordering, max page size. |
| [`api/streaming.md`](./references/api/streaming.md) | Unary vs server/client/bidi, when each, deadlines, prefer pagination over streaming for lists. |
| [`api/versioning.md`](./references/api/versioning.md) | Version in the package path, evolve-in-place vs bump, running v1+v2 in parallel, deprecation timeline. |

## 🛠️ Toolkit

| File | When to Read |
|---|---|
| [`toolkit/easyp.md`](./references/toolkit/easyp.md) | **EasyP** is the primary toolchain: `easyp.yaml` (lint/breaking/deps/gen), module layout, dependencies. buf fallback notes included. |
| [`toolkit/lint.md`](./references/toolkit/lint.md) | Recommended rule set, enable/disable policy, common violations + fixes. |
| [`toolkit/breaking.md`](./references/toolkit/breaking.md) | Breaking detection in CI against a baseline git ref; what counts as breaking. |
| [`toolkit/codegen.md`](./references/toolkit/codegen.md) | Plugins (go, go-grpc, gateway, protovalidate, openapi), committing artifacts, `go_package`, determinism. |
| [`toolkit/ci.md`](./references/toolkit/ci.md) | Lint + breaking + gen-freshness gate in CI; fail on drift. |

## 🔌 Integration

| File | When to Read |
|---|---|
| [`integration/grpc-gateway.md`](./references/integration/grpc-gateway.md) | REST mapping via `google.api.http`, path/body/query mapping, `additional_bindings`, OpenAPI output. |
| [`integration/protovalidate.md`](./references/integration/protovalidate.md) | Declarative `buf.validate` (CEL) constraints, replacing protoc-gen-validate, one validation interceptor. |
| [`integration/json-mapping.md`](./references/integration/json-mapping.md) | proto3 JSON: lowerCamelCase (`json_name`), enums as strings, 64-bit ints as strings, WKT JSON forms, emit-defaults. |

## 📦 Assets (copy-paste starters)

| File | Use |
|---|---|
| [`assets/easyp.yaml`](./assets/easyp.yaml) | Starter EasyP config (lint + breaking + deps + gen) — the default toolchain. |
| [`assets/buf.gen.yaml`](./assets/buf.gen.yaml) | Fallback buf generation config; use only if migrating from buf. |
| [`assets/example.v1.proto`](./assets/example.v1.proto) | One exemplary file exercising every convention end-to-end. |
| [`assets/Taskfile.proto.yml`](./assets/Taskfile.proto.yml) | Task targets: `proto-lint`, `proto-breaking`, `proto-gen`, `proto-format`. |
