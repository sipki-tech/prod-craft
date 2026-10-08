---
name: proto-craft
description: "Professional Protocol Buffers craft: idiomatic .proto style, schema design and evolution, wire compatibility, resource-oriented gRPC API design, error model, pagination, and EasyP tooling (buf as fallback) — distilled from the Protobuf Language Guide, Google API Improvement Proposals (AIPs), and production schema patterns. Use when: writing or reviewing .proto; naming; field numbers and presence; enums; well-known types; message/oneof design; backward/forward compatibility and versioning; service and RPC design; google.rpc.Status errors; cursor pagination; grpc-gateway REST mapping; protovalidate; EasyP lint, breaking-change checks, and codegen (buf as fallback). ACTIVELY TRIGGER whenever authoring or reviewing .proto or designing/evolving a gRPC API. Not for basic syntax tutorials."
---

# `proto-craft`

Idiomatic, professional-grade standards for Protocol Buffers: style, schema design, evolution, API shape, error model, and tooling.

## How to Use This Skill
**Do not implement from this file.** It is only the entry point. Find the precise rules in the **Navigation Map**, load only the few files relevant to the task, and enforce them.

👉 **[Read MAP.md](./MAP.md)** 👈

## When to Use
- Writing, reviewing, or refactoring a `.proto` schema or a gRPC API.
- Deciding a field number, presence mode, enum shape, or message/`oneof` layout.
- Evolving a schema safely (additive change, deprecation, breaking change → new version).
- Designing services, methods, errors, pagination, or REST mapping; configuring EasyP lint, breaking, and codegen (buf fallback).

## Decision Flow — which files to load
- Naming / file layout / field numbers / presence / enums / well-known types / comments → `style/*`.
- Message & `oneof` shape / compatibility table / evolution / defaults → `schema/*`.
- Service & RPC design / errors / pagination / streaming / versioning → `api/*`.
- EasyP v1 (`protobuf.mod`, `easyp.yaml`, `easyp.gen.yaml`, `protobuf.lock`), lint rule set, breaking checks, codegen, CI gate → `toolkit/*`. A v0 `easyp.yaml` (`deps:`, `lint.use`, `generate.inputs`) → migrate with `easyp migrate` (`toolkit/easyp.md`).
- REST mapping, `protovalidate` constraints, proto3 JSON → `integration/*`.

## Non-Negotiables
Three rules cut across every file:
1. **Wire compatibility is sacred.** Field numbers are permanent: never change, renumber, or reuse them; `reserved` the numbers **and** names on deletion; any wire-breaking change requires a new package version. (`schema/compatibility.md`, `schema/evolution.md`)
2. **Zero values and request/response shape are fixed.** Every enum's first value is `*_UNSPECIFIED = 0`; every RPC defines its own named `XRequest` and `XResponse` — no bare scalars, no shared request messages. (`style/enums.md`, `api/services.md`)
3. **Resource-oriented, evolvable APIs.** Standard methods, cursor pagination, and the `google.rpc.Status` + `errdetails` error model. (`api/*`)

## Review Checklist
Run before approving a `.proto` change:
1. `syntax = "proto3"`; package is reverse-DNS + version (`acme.user.v1`); `option go_package` set.
2. Field numbers never changed or reused; deleted fields have their numbers **and** names `reserved`.
3. Every enum starts with `*_UNSPECIFIED = 0`; values are `CONSTANT_CASE` with a type-name prefix.
4. Each RPC has its own named `XRequest`/`XResponse`; no bare scalars; no shared request messages.
5. Timestamps/durations use well-known types; partial updates use `FieldMask`; `Any` only as a last resort.
6. `List` methods use cursor pagination (`page_size` + opaque `page_token` → `next_page_token`) with stable ordering and a bounded max.
7. Errors map to canonical codes via `google.rpc.Status` + `errdetails`; no internal details leaked.
8. Doc comments on every message, field, service, and RPC; units, invariants, and deprecation are stated.
9. Constraints declared with `protovalidate`; `google.api.http` mapping present wherever REST is exposed.
10. `easyp lint` and `easyp breaking` are clean against the baseline; generated artifacts regenerated and committed.

Always apply these standards when writing or reviewing Protocol Buffers.
