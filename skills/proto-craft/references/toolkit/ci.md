# CI Gate

CI is where the conventions become non-negotiable. Gate every PR on lint, breaking, and generated-artifact freshness.

## Three required checks
Make lint, breaking, and gen-freshness all required statuses for merge.
- **Reason:** Local runs are advisory; only a required check prevents a non-conforming or incompatible schema from landing. See [`lint.md`](./lint.md) and [`breaking.md`](./breaking.md).

```bash
easyp lint
easyp breaking --against <main-branch-or-release-tag>
# then verify generated code is in sync (below)
```

## Fail on generation drift
Regenerate in CI and fail if the working tree changes — proving committed artifacts match the `.proto`.
- **Reason:** Committed-but-stale generated code is a silent contract lie; the diff check guarantees `*.pb.go` etc. reflect the current schema. See [`codegen.md`](./codegen.md).

```bash
easyp generate
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
go install github.com/easyp-tech/easyp/cmd/easyp@<pinned-version>
```

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
- [ ] `easyp generate` + `git diff --exit-code` enforces artifact freshness.
- [ ] Breaking compares against the target branch tip / release tag.
- [ ] CI pins tool and plugin versions.
- [ ] The same checks run locally via task targets.
