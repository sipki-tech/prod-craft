# Toolchain: EasyP

Treat `.proto` as the single source of truth and drive everything through one tool. **EasyP v1** is the default and recommended toolchain. buf fallback notes are included for teams migrating from buf, but new projects should always start with EasyP.

## Four files at the module root
EasyP v1 splits configuration by role. Keep all four next to each other at the repo root; the proto sources live under `api/`.

| File | Role |
|---|---|
| `protobuf.mod` | Module identity, import roots, dependencies |
| `protobuf.lock` | Exact commit + hash of every dependency (generated) |
| `easyp.yaml` | Lint and breaking policy |
| `easyp.gen.yaml` | Code generation plugins |

- **Reason:** With the config at the repo root, every contributor and CI get the same reproducible toolchain without per-directory setup. Splitting the files by role keeps policy, dependencies and codegen reviewable on their own. See [`../style/files.md`](../style/files.md).

```text
# protobuf.mod
module github.com/acme/contracts

roots (
	api
)

require (
	github.com/googleapis/googleapis
	github.com/grpc-ecosystem/grpc-gateway
	github.com/bufbuild/protovalidate
)
```

```yaml
# easyp.yaml — lint + breaking policy
version: v1
linters:
  default: STANDARD
breaking:
  baseline: git:main
  categories: [WIRE_JSON]
```

Start from the starters: [`../../assets/protobuf-starter.mod`](../../assets/protobuf-starter.mod), [`../../assets/easyp-starter.yaml`](../../assets/easyp-starter.yaml) and [`../../assets/easyp.gen-starter.yaml`](../../assets/easyp.gen-starter.yaml). Rename them on copy. They are not named `easyp.yaml` on purpose: `easyp validate-config` scans every directory and would treat a template as config.

## Still on EasyP v0?
A single `easyp.yaml` with top-level `deps:`, `lint.use` or `generate.inputs`, often with `version: v1alpha` and an `easyp.lock`, is EasyP **v0** configuration. A v1 binary refuses it with `legacy EasyP configuration detected`. Migrate with `easyp migrate --module <identity>`: it previews by default, then apply with `--resolve-lock --write`. Do not hand-convert.
- **Reason:** `easyp migrate` verifies the old pins and preserves the exact lint rule set. Hand conversion silently changes behaviour. The full procedure (baseline, blockers, parity check, CI) is in the EasyP skill [`protobuf-expert-skill`](https://github.com/easyp-tech/protobuf-expert-skill), `references/migration-v0-to-v1.md`.

## buf fallback
buf splits the same configuration into `buf.yaml` (module/lint/breaking), `buf.gen.yaml` (plugins) and `buf.lock`, which map 1:1 onto the files above. `easyp init` refuses to run next to a `buf.yaml`, so convert by hand.
- **Reason:** Knowing the mapping eases migration from buf to EasyP. See [`codegen.md`](./codegen.md).

<details>
<summary>buf.yaml equivalent (for reference only)</summary>

```yaml
# buf.yaml — fallback only
version: v2
modules:
  - path: api
lint:
  use:
    - STANDARD
breaking:
  use:
    - WIRE_JSON
```

</details>

## Declare dependencies, don't vendor protos by hand
Add external proto modules (`googleapis`, `grpc-gateway`, `protovalidate`) to `protobuf.mod` and let EasyP pin them in `protobuf.lock`. Commit both files.
- **Reason:** Managed deps give reproducible, pinned imports for well-known types and annotations. Hand-copied protos drift and break breaking-change analysis.

```bash
easyp get github.com/bufbuild/protovalidate   # add one dependency (buf fallback: buf dep update)
easyp mod tidy                                # after editing protobuf.mod by hand: resolve + write the lock
easyp --frozen mod download                   # CI: install exactly what the lock pins
```

## Three commands, one workflow
Standardize on lint, breaking, and generate. Wire them into a task runner (see [`../../assets/Taskfile.proto.yml`](../../assets/Taskfile.proto.yml)).
- **Reason:** A fixed command set keeps local and CI behaviour identical and removes ad hoc `protoc` scripts. Details live in [`lint.md`](./lint.md), [`breaking.md`](./breaking.md), [`codegen.md`](./codegen.md), and [`ci.md`](./ci.md).

```bash
easyp lint                               # style rules
easyp breaking --against <baseline-ref>  # compatibility guard
easyp generate                           # codegen (easyp.gen.yaml)
```

EasyP has no formatter. If you format protos, use `buf format -w` as a standalone tool; it does not need any buf config.

## Checklist
- [ ] `protobuf.mod`, `protobuf.lock`, `easyp.yaml`, `easyp.gen.yaml` at the repo root; sources under `api/`.
- [ ] External protos declared in `protobuf.mod` and locked, not hand-vendored.
- [ ] No v0 `easyp.yaml` left anywhere in the tree (`easyp validate-config` is clean).
- [ ] Lint, breaking, and generate wired into the task runner.
- [ ] One toolchain chosen consistently across the repo and CI.
