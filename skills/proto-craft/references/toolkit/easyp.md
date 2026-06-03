# Toolchain: EasyP

Treat `.proto` as the single source of truth and drive everything through one tool. **EasyP** (`easyp.yaml`) is the default and recommended toolchain. buf fallback notes are included for teams migrating from buf, but new projects should always start with EasyP.

## One config at the repo root
Keep a single `easyp.yaml` at the repo root declaring dependencies, lint, breaking, and generation. The proto module lives under `api/`.
- **Reason:** A repo-root config makes the toolchain reproducible for every contributor and CI without per-directory setup. See [`../style/files.md`](../style/files.md).

```yaml
# easyp.yaml — primary toolchain
version: v1alpha
deps:
  - github.com/googleapis/googleapis
  - github.com/grpc-ecosystem/grpc-gateway
  - github.com/bufbuild/protovalidate
lint:
  use:
    - DEFAULT
```

## buf fallback
If migrating from buf, the equivalent splits config into `buf.yaml` (module/lint/breaking) and `buf.gen.yaml` (plugins). EasyP is a drop-in replacement.
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
    - FILE
```

</details>

## Declare dependencies, don't vendor protos by hand
List external proto modules (`googleapis`, `grpc-gateway`, `protovalidate`) under `deps` and let the tool fetch them into a lock file.
- **Reason:** Managed deps give reproducible, pinned imports for well-known types and annotations; hand-copied protos drift and break breaking-change analysis.

```bash
easyp mod download   # buf fallback: buf dep update
```

## Four commands, one workflow
Standardize on lint, breaking, generate, and format. Wire them into a task runner (see [`../../assets/Taskfile.proto.yml`](../../assets/Taskfile.proto.yml)).
- **Reason:** A fixed command set keeps local and CI behavior identical and removes ad hoc `protoc` scripts. Details live in [`lint.md`](./lint.md), [`breaking.md`](./breaking.md), [`codegen.md`](./codegen.md), and [`ci.md`](./ci.md).

```bash
easyp lint                               # style rules
easyp breaking --against <baseline-ref>  # compatibility guard
easyp generate                           # codegen
easyp format -w                          # canonical formatter
```

## Checklist
- [ ] Single `easyp.yaml` at the repo root; module under `api/`.
- [ ] External protos declared in `deps` and locked, not hand-vendored.
- [ ] Lint, breaking, generate, and format wired into the task runner.
- [ ] One toolchain chosen consistently across the repo and CI.
