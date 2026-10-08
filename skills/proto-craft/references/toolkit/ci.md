# CI Gate

CI is where the conventions become non-negotiable. Gate every PR on lint, breaking, and generated-artifact freshness.

## Three required checks
Make lint, breaking, and gen-freshness all required statuses for merge.
- **Reason:** Local runs are advisory; only a required check prevents a non-conforming or incompatible schema from landing. See [`lint.md`](./lint.md) and [`breaking.md`](./breaking.md).

```bash
easyp --frozen mod download            # exactly what protobuf.lock pins; never re-resolves
easyp --frozen lint
easyp --frozen breaking --against <main-branch-or-release-tag>
# then verify generated code is in sync (below)
```

`--frozen` is explicit; `CI=true` does not imply it. It fails when `protobuf.mod` and `protobuf.lock` disagree, instead of silently re-resolving.

## Fail on generation drift
Regenerate in CI and fail if the working tree changes — proving committed artifacts match the `.proto`.
- **Reason:** Committed-but-stale generated code is a silent contract lie; the diff check guarantees `*.pb.go` etc. reflect the current schema. See [`codegen.md`](./codegen.md).

```bash
easyp --frozen generate
git diff --exit-code   # non-zero if generated output drifted from commits
```

## Run breaking against the merge base
Configure the breaking step to compare the PR against the target branch's tip.
- **Reason:** This catches breaks introduced anywhere in the branch relative to what consumers run, not just the latest commit. See [`breaking.md`](./breaking.md).

```bash
easyp breaking --against origin/main
# buf fallback: buf breaking --against '.git#branch=main'
```

## Pin tool and plugin versions in CI
Install a pinned EasyP version and pinned plugins in the CI job.
- **Reason:** A floating toolchain makes CI non-reproducible and can flip lint/gen results between runs; pinning keeps the gate stable. See [`codegen.md`](./codegen.md).

```bash
# EasyP v1 ships as nightly tags; @latest and brew still install v0.17.0
go install github.com/easyp-tech/easyp/cmd/easyp@v1.0.0-nightly.20261008.1
# or the image ghcr.io/easyp-tech/easyp:v1.0.0-nightly.20261008.1
```

Cache `~/.easyp/v1` keyed on `protobuf.lock`. With `easyp-tech/actions/{lint,breaking}@v1`, always set `with: version: <nightly tag>`: the action's default image is v0.

## Mirror the gate locally via the task runner
Expose the same checks as task targets so contributors reproduce CI before pushing.
- **Reason:** A one-command local gate cuts the red-CI feedback loop. See [`../../assets/Taskfile.proto.yml`](../../assets/Taskfile.proto.yml).

```bash
task proto-lint
task proto-breaking
task proto-gen
```

## Checklist
- [ ] Lint, breaking, and gen-freshness are required PR checks.
- [ ] `easyp --frozen generate` + `git diff --exit-code` enforces artifact freshness.
- [ ] `protobuf.mod` and `protobuf.lock` are committed; CI runs with `--frozen`.
- [ ] Breaking compares against the target branch tip / release tag.
- [ ] CI pins tool and plugin versions.
- [ ] The same checks run locally via task targets.
